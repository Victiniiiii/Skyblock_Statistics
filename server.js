const express = require("express");
const bodyParser = require("body-parser");
const cors = require("cors");
const { ProfileNetworthCalculator } = require("skyhelper-networth");

const app = express();
const port = 3000;

app.use(cors());
app.use(bodyParser.json({ limit: "10mb" }));

app.post("/networth", async (req, res) => {
	try {
		const { profileData, museumData, bankBalance } = req.body;

		if (!profileData || !museumData) {
			return res.status(400).json({ error: "Missing profileData or museumData" });
		}

		const calculator = new ProfileNetworthCalculator(profileData, museumData, bankBalance || 0);
		const networth = await calculator.getNetworth();
		res.json(networth);
	} catch (err) {
		console.error("Networth calculation failed:", err);
		res.status(500).json({ error: "Networth calculation failed" });
	}
});

app.listen(port, () => {
	console.log(`Networth microservice running at http://localhost:${port}`);
});
