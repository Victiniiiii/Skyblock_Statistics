const fs = require("fs");
const https = require("https");

const apiKey = fs.readFileSync("config.txt", "utf-8").trim();
const uuids = fs
	.readFileSync("uuids.txt", "utf-8")
	.split("\n")
	.map((x) => x.trim())
	.filter((x) => x);

let progress = { index: 0, requestsMade: 0, date: new Date().toISOString().split("T")[0] };
if (fs.existsSync("progress.json")) {
	const p = JSON.parse(fs.readFileSync("progress.json", "utf-8"));
	if (p.date === progress.date) progress = p; // same day
}

const dataPath = "data.json";
let existingData = [];
if (fs.existsSync(dataPath)) existingData = JSON.parse(fs.readFileSync(dataPath, "utf-8"));

(async () => {
	for (; progress.index < uuids.length && progress.requestsMade < 5000; progress.index++, progress.requestsMade++) {
		const uuid = uuids[progress.index];
		const url = `https://api.hypixel.net/v2/skyblock/profiles?uuid=${uuid}&key=${apiKey}`;

		await new Promise((resolve) => {
			https
				.get(url, (res) => {
					let body = "";
					res.on("data", (chunk) => (body += chunk));
					res.on("end", () => {
						try {
							existingData.push({ uuid, response: JSON.parse(body), timestamp: new Date().toISOString() });
						} catch (e) {
							console.error(`Error parsing response for ${uuid}`);
						}
						fs.writeFileSync("data.json", JSON.stringify(existingData, null, 2));
						fs.writeFileSync("progress.json", JSON.stringify(progress, null, 2));
						console.log(`Fetched ${uuid}, ${progress.index} of ${uuids.length} uuids.`);
						resolve();
					});
				})
				.on("error", (e) => {
					console.error(`Failed ${uuid}: ${e.message}`);
					resolve();
				});
		});
	}

	console.log(`Done. Requests today: ${progress.requestsMade}`);
})();
