const fs = require("fs");
const path = require("path");
const { ProfileNetworthCalculator } = require("skyhelper-networth");
const { createObjectCsvWriter } = require("csv-writer");
const ProgressBar = require("progress");

const apiKey = fs.readFileSync("txt", "utf8").trim();
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
	const res = await fetch(url);
	if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
	return await res.json();
}

async function getProfileData(uuid, retries = 3) {
	const url = `https://api.hypixel.net/v2/skyblock/profiles?uuid=${uuid}&key=${apiKey}`;
	for (let i = 1; i <= retries; i++) {
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
			if (i === retries) {
				console.error(`❌ Profile error for ${uuid}: ${err.message}`);
				return null;
			}
			console.warn(`⚠️ Retry ${i} for ${uuid}: ${err.message}`);
			await new Promise((r) => setTimeout(r, 1500 * i));
		}
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
	const result = await calculator.calculateNetworth();
	return result.networth;
}

async function main() {
	const uuids = fs
		.readFileSync(uuidFile, "utf8")
		.split("\n")
		.map((l) => l.trim())
		.filter(Boolean);

	let { processed, index, total } = loadState();
	total = total || uuids.length;

	const csvWriter = createObjectCsvWriter({
		path: outputFile,
		header: [
			{ id: "uuid", title: "UUID" },
			{ id: "magical_power", title: "MagicalPower" },
			{ id: "level", title: "Level" },
			{ id: "networth", title: "Networth" },
		],
		append: fs.existsSync(outputFile),
	});

	const bar = new ProgressBar("[:bar] :current/:total ETA: :etas", {
		total,
		width: 30,
		curr: index,
	});

	for (let i = index; i < uuids.length; i++) {
		const uuid = uuids[i];
		if (processed.includes(uuid)) {
			bar.tick();
			continue;
		}

		saveState(processed, i, total);
		const prof = await getProfileData(uuid);
		if (!prof) {
			bar.tick();
			continue;
		}

		let museum;
		try {
			museum = await getMuseumData(uuid, prof.profileId);
		} catch (e) {
			console.error(`❌ Museum error for ${uuid}: ${e.message}`);
			bar.tick();
			continue;
		}

		try {
			const networth = await calculateNetworth(prof.profileData, museum, prof.bankBalance);
			const mp = prof.profileData.accessory_bag_storage?.highest_magical_power || 0;
			const lvl = (prof.profileData.leveling?.experience || 0) / 100;
			await csvWriter.writeRecords([{ uuid, magical_power: mp, level: lvl, networth: networth.toFixed(2) }]);
			console.log(`✅ ${uuid} — Level: ${lvl.toFixed(2)} | MP: ${mp} | NW: ${networth.toFixed(2)}`);
			processed.push(uuid);
		} catch (e) {
			console.error(`❌ Calculation error for ${uuid}: ${e.message}`);
		}

		bar.tick();
		saveState(processed, i + 1, total);
	}

	console.log(`\n🎉 Data collection complete: ${processed.length}/${total}`);
	saveState([], 0, total);
}

main();
