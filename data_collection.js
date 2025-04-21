const fs = require("fs");
const { ProfileNetworthCalculator } = require("skyhelper-networth");

const apiKey = fs.readFileSync("config.txt", "utf8").trim();
const uuidFile = "uuids.txt";
const stateFile = "data_state.json";
const outputFile = "player_data.csv";

const MAX_THROTTLE_ERRORS = 10;
const THROTTLE_COOLDOWN_BASE = 5000;
let throttleErrors = 0;

function loadState() {
	if (fs.existsSync(stateFile)) {
		const s = JSON.parse(fs.readFileSync(stateFile));
		return {
			processed: s.processed || [],
			index: s.index || 0,
			total: s.total || null,
			lastThrottleTime: s.lastThrottleTime || 0,
		};
	}
	return { processed: [], index: 0, total: null, lastThrottleTime: 0 };
}

function saveState(processed, index, total, lastThrottleTime) {
	fs.writeFileSync(stateFile, JSON.stringify({ processed, index, total, lastThrottleTime }, null, 2));
}

async function fetchJSON(url) {
	const state = loadState();

	const timeSinceLastThrottle = Date.now() - state.lastThrottleTime;
	if (state.lastThrottleTime > 0 && timeSinceLastThrottle < THROTTLE_COOLDOWN_BASE) {
		const waitTime = THROTTLE_COOLDOWN_BASE - timeSinceLastThrottle;
		console.log(`⏳ Waiting ${waitTime}ms due to recent throttling...`);
		await new Promise((resolve) => setTimeout(resolve, waitTime));
	}

	for (let i = 1; i <= 3; i++) {
		try {
			const res = await fetch(url);

			if (res.status === 429) {
				throttleErrors++;
				console.warn(`⚠️ Rate limited (429). Retry ${i}/3... (Total: ${throttleErrors}/${MAX_THROTTLE_ERRORS})`);

				if (throttleErrors >= MAX_THROTTLE_ERRORS) {
					throw new Error("Maximum throttle errors reached. Stopping execution.");
				}

				const backoffTime = THROTTLE_COOLDOWN_BASE * Math.pow(2, i);
				console.log(`⏳ Backing off for ${backoffTime}ms...`);
				await new Promise((r) => setTimeout(r, backoffTime));
				continue;
			}

			if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
			const data = await res.json();

			if (data.throttle === true) {
				throttleErrors++;
				const throttleTime = Date.now();
				saveState(state.processed, state.index, state.total, throttleTime);

				console.warn(`⚠️ API throttled (${data.cause}). Retry ${i}/3... (Total: ${throttleErrors}/${MAX_THROTTLE_ERRORS})`);

				if (throttleErrors >= MAX_THROTTLE_ERRORS) {
					throw new Error("Maximum throttle errors reached. Stopping execution.");
				}

				const backoffTime = THROTTLE_COOLDOWN_BASE * Math.pow(2, i);
				console.log(`⏳ Backing off for ${backoffTime}ms...`);
				await new Promise((r) => setTimeout(r, backoffTime));
				continue;
			}

			return data;
		} catch (err) {
			if (i === 3 || (!err.message.includes("Fetch failed: 429") && !err.message.includes("Maximum throttle errors"))) {
				throw err;
			}

			if (err.message.includes("Maximum throttle errors")) {
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
		if (!data.success) {
			if (data.cause === "Key throttle" && data.throttle === true) {
				throw new Error("API throttled");
			}
			throw new Error(`API returned error: ${data.cause || "Unknown error"}`);
		}

		if (!data.profiles?.length) throw new Error("No profile data");
		const sel = data.profiles.find((p) => p.selected);
		if (!sel) throw new Error("No selected profile");
		return {
			profileData: sel.members[uuid],
			bankBalance: (sel.banking && sel.banking.balance) || 0,
			profileId: sel.profile_id,
		};
	} catch (err) {
		console.error(`❌ Profile error for ${uuid}: ${err.message}`);
		if (err.message.includes("Maximum throttle errors") || err.message.includes("API throttled")) {
			throw err;
		}
		return null;
	}
}

async function getMuseumData(uuid, profileId) {
	const url = `https://api.hypixel.net/v2/skyblock/museum?profile=${profileId}&key=${apiKey}`;
	try {
		const data = await fetchJSON(url);
		if (!data.success) {
			if (data.cause === "Key throttle" && data.throttle === true) {
				throw new Error("API throttled");
			}
			throw new Error(`API returned error: ${data.cause || "Unknown error"}`);
		}

		if (!data.members[uuid]) {
			throw new Error("Museum data missing");
		}
		return data.members[uuid];
	} catch (err) {
		if (err.message.includes("Maximum throttle errors") || err.message.includes("API throttled")) {
			throw err;
		}
		throw err;
	}
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

	let { processed, index, total, lastThrottleTime } = loadState();
	total = total || uuids.length;

	const isFirstWrite = !fs.existsSync(outputFile);

	console.log(`Starting processing at index ${index}/${total} (${processed.length} already processed)`);

	if (lastThrottleTime > 0) {
		const timeSinceLastThrottle = Date.now() - lastThrottleTime;
		if (timeSinceLastThrottle < THROTTLE_COOLDOWN_BASE * 2) {
			const waitTime = Math.max(0, THROTTLE_COOLDOWN_BASE * 2 - timeSinceLastThrottle);
			console.log(`⏳ Waiting ${waitTime}ms before starting due to previous throttling...`);
			await new Promise((resolve) => setTimeout(resolve, waitTime));
		}
	}

	try {
		for (let i = index; i < uuids.length; i++) {
			const uuid = uuids[i];
			if (processed.includes(uuid)) {
				continue;
			}

			const currentPosition = i + 1;
			const progressPercentage = ((currentPosition / total) * 100).toFixed(2);
			console.log(`📊 Processing ${currentPosition}/${total} (${progressPercentage}%) - UUID: ${uuid}`);

			saveState(processed, i, total, lastThrottleTime);

			if (i > index) {
				await new Promise((resolve) => setTimeout(resolve, 300));
			}

			const prof = await getProfileData(uuid);
			if (!prof) {
				continue;
			}

			let museum;
			try {
				museum = await getMuseumData(uuid, prof.profileId);
			} catch (e) {
				console.error(`❌ Museum error for ${uuid}: ${e.message}`);
				if (e.message.includes("Maximum throttle errors") || e.message.includes("API throttled")) {
					throw e;
				}
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
                throttleErrors = 0;
			} catch (e) {
				console.error(`❌ Calculation error for ${uuid}: ${e.message}`);
				if (e.message.includes("Maximum throttle errors") || e.message.includes("API throttled")) {
					throw e;
				}
			}

			saveState(processed, i + 1, total, lastThrottleTime);
		}

		console.log(`\n🎉 Data collection complete: ${processed.length}/${total} (100%)`);
		saveState([], 0, total, 0);
	} catch (error) {
		if (error.message.includes("Maximum throttle errors") || error.message.includes("API throttled")) {
			console.log(`\n⛔ Stopping execution after ${MAX_THROTTLE_ERRORS} throttle errors.`);
			console.log(`Progress saved at index ${index}. Run the script again later.`);
		} else {
			console.error(`\n❌ Unexpected error: ${error.message}`);
		}
	}
}

main();
