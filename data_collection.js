const fs = require("fs");
const path = require("path");
const { ProfileNetworthCalculator } = require("skyhelper-networth");

const apiKey = fs.readFileSync("config.txt", "utf8").trim();
const uuidFile = "uuids.txt";
const stateFile = "data_state.json";
const outputFile = "player_data.csv";

function loadState() {
	if (fs.existsSync(stateFile)) {
		const s = JSON.parse(fs.readFileSync(stateFile));
		return {
			processed: s.processed || [],
			index: s.index || 0,
			total: s.total || null,
		};
	}
	return { processed: [], index: 0, total: null };
}

function saveState(processed, index, total) {
	fs.writeFileSync(stateFile, JSON.stringify({ processed, index, total }, null, 2));
}

async function fetchJSON(url) {
	for (let i = 1; i <= 3; i++) {
		try {
			const res = await fetch(url);
			if (res.status === 429) {
				console.warn(`⚠️ Rate limited (429). Retry ${i}/3...`);
				await new Promise((r) => setTimeout(r, 1500 * i));
				continue;
			}
			if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
			return await res.json();
		} catch (err) {
			if (i === 3 || err.message !== "Fetch failed: 429") {
				throw err;
			}
		}
	}
	throw new Error("Max retries reached");
}

async function getProfileData(uuid) {
	const url = `https://api.hypixel.net/v2/skyblock/profiles?uuid=${uuid}&key=${apiKey}`;
	try {
		const data = await fetchJSON(url);
		if (!data.success || !data.profiles?.length) throw new Error("No profile data");
		const sel = data.profiles.find((p) => p.selected);
		if (!sel) throw new Error("No selected profile");
		return {
			profileData: sel.members[uuid],
			bankBalance: (sel.banking && sel.banking.balance) || 0,
			profileId: sel.profile_id,
		};
	} catch (err) {
		console.error(`❌ Profile error for ${uuid}: ${err.message}`);
		return null;
	}
}

async function getMuseumData(uuid, profileId) {
	const url = `https://api.hypixel.net/v2/skyblock/museum?profile=${profileId}&key=${apiKey}`;
	const data = await fetchJSON(url);
	if (!data.success || !data.members[uuid]) {
		throw new Error("Museum data missing");
	}
	return data.members[uuid];
}

async function calculateNetworth(profileData, museumData, bankBalance) {
	const calculator = new ProfileNetworthCalculator(profileData, museumData, bankBalance);
	const result = await calculator.getNetworth();
	return result.networth;
}

function writeCsvRow(filePath, row, isFirstWrite = false) {
	const line = `"${row.uuid}",${row.magical_power},${row.level},"${row.networth}"\n`;
	if (isFirstWrite) {
		const header = "UUID,MagicalPower,Level,Networth\n";
		fs.writeFileSync(filePath, header + line, { encoding: "utf8" });
	} else {
		fs.appendFileSync(filePath, line, { encoding: "utf8" });
	}
}

async function main() {
	const uuids = fs
		.readFileSync(uuidFile, "utf8")
		.split("\n")
		.map((l) => l.trim())
		.filter(Boolean);

	let { processed, index, total } = loadState();
	total = total || uuids.length;

	const isFirstWrite = !fs.existsSync(outputFile);
	
	console.log(`Starting processing at index ${index}/${total} (${processed.length} already processed)`);

	for (let i = index; i < uuids.length; i++) {
		const uuid = uuids[i];
		if (processed.includes(uuid)) {
			continue;
		}

		const currentPosition = i + 1;
		const progressPercentage = ((currentPosition / total) * 100).toFixed(2);
		console.log(`📊 Processing ${currentPosition}/${total} (${progressPercentage}%) - UUID: ${uuid}`);

		saveState(processed, i, total);
		const prof = await getProfileData(uuid);
		if (!prof) {
			continue;
		}

		let museum;
		try {
			museum = await getMuseumData(uuid, prof.profileId);
		} catch (e) {
			console.error(`❌ Museum error for ${uuid}: ${e.message}`);
			continue;
		}

		try {
			const networth = await calculateNetworth(prof.profileData, museum, prof.bankBalance);
			const mp = prof.profileData.accessory_bag_storage?.highest_magical_power || 0;
			const lvl = (prof.profileData.leveling?.experience || 0) / 100;

			writeCsvRow(
				outputFile,
				{
					uuid,
					magical_power: mp,
					level: lvl.toFixed(2),
					networth: networth.toFixed(2),
				},
				isFirstWrite && i === index
			);

			console.log(`✅ ${uuid} — Level: ${lvl.toFixed(2)} | MP: ${mp} | NW: ${networth.toFixed(2)}`);
			processed.push(uuid);
		} catch (e) {
			console.error(`❌ Calculation error for ${uuid}: ${e.message}`);
		}

		const completedCount = processed.length;
		const completionPercentage = ((completedCount / total) * 100).toFixed(2);
		console.log(`📈 Progress: ${completedCount}/${total} (${completionPercentage}% complete)`);
		
		saveState(processed, i + 1, total);
	}

	console.log(`\n🎉 Data collection complete: ${processed.length}/${total} (100%)`);
	saveState([], 0, total);
}

main();