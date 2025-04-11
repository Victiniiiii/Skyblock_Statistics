# 📊 Hypixel Skyblock Statistics Correlation Project

## 🔍 What is this?
This is a statistics-focused project that explores correlations between **Player Level**, **Net Worth**, and **Magical Power** in the online game *Hypixel Skyblock*.  

The goal is to:
- Understand how strongly these stats are related
- Enable players to benchmark themselves — e.g., "For my level, is my Magical Power above or below average?"

This is primarily an **exploratory data analysis** project using real scraped player data, with visualizations as the main output.

---

## 🚀 How to Run This

### 1. Configuration
Create a file named `config.txt` and paste your Hypixel API key into it.  
Get an API key here: [https://developer.hypixel.net/](https://developer.hypixel.net/)

### 2. Install Dependencies

#### 🐍 Python (for scraping usernames)
Install the required packages using pip:
```
pip install selenium aiohttp asyncio_throttle requests logging
```

#### 🧮 R (for data analysis & plotting)
Install the following R libraries:
```
install.packages(c(
  "ggplot2",     
  "gridExtra",   
  "scales",     
  "httr",   
  "jsonlite",    
  "data.table"  
))

```

#### 🟢 Node.js (for net worth calculations)
```
npm install express skyhelper-networth body-parser cors
```
Make sure Node.js and npm are installed on your system.

---

## 🔄 Username Gathering Workflow

### Step 1: Scrape Forum Usernames
```
python username_finder.py
```
Scrapes Minecraft usernames from Hypixel forums. Outputs a base list of ~2,000 usernames.

### Step 2: Scrape Soopy Leaderboards
```
Rscript scrape_soopy.r
```
Uses Soopy API to collect usernames of the top 10,000 players across multiple leaderboards. Adds ~35,000 usernames, most of which are high-level.

### Step 3: Expand via Guild Memberships
```
python guild_checker.py
```
For each username, checks their guild and extracts guildmates. This helps balance the dataset by adding mid/low-level players.

→ Expected to add ~[INSERT ROUGH COUNT] more usernames. (Update this once known.)

### Step 4: Merge and Deduplicate
```
Rscript log_extract.r
```
Combines all gathered usernames and removes duplicates. Prepares player_list.txt as the unified input list.

---

## 📥 Data Collection

Make sure your Node.js server is running:
```
node server.js
```

Then run the R script:
```
Rscript data_collection.r
```

This generates `player_data.csv`, which contains:
- username
- level
- magical_power
- networth

Players with disabled APIs are excluded to maintain data quality.

---

## 📈 Plotting Results

Once `player_data.csv` is ready, generate the plots:
```
Rscript data_plotting.r
```

This will output three plots:
- Level vs Net Worth
- Level vs Magical Power
- Net Worth vs Magical Power

These plots help visualize trends and correlations across the player base.

---

## 📤 Output (Work In Progress)

Final results are still running. This section will be updated with the complete data visualizations and summary of findings.

✅ All gathered data and plots will be free to use once published.

---

## 📄 License and Credits

All data in this repository is free to use.

Special thanks to:
- SkyHelper-Networth (Networth Calculation)
- Soopy API
- Mojang API
- Hypixel API

---

## 🧠 Future Improvements

- Add regression analysis or clustering on the stats
- Automate the entire pipeline via a wrapper script
- Include summary statistics (mean, median, standard deviation) in the plots
- Export final report as PDF or Markdown slide deck