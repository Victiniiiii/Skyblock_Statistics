# 📊 Hypixel Skyblock Statistics Correlation Project

## 🔍 What is this?
This is a statistics-focused project that explores correlations between **Player Level**, **Net Worth** (How rich a player is), and **Magical Power** (How strong a player is) in the online game *Hypixel Skyblock*.  

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
pip install aiohttp asyncio-throttle
```

#### 🧮 R (for data analysis & plotting)
Install the following R libraries:
```
install.packages(c("ggplot2", "gridExtra", "scales", "broom", "dplyr", "GGally"))
```

#### 🟢 Node.js (for net worth calculations)
```
npm install skyhelper-networth
```
Make sure Node.js and npm are installed on your system.

---

## 🔄 Username Gathering Workflow

### Step 1: Scrape Soopy Leaderboards
```
Rscript scrape_soopy.r
```
Uses Soopy API to collect usernames of the top 10,000 players across multiple leaderboards. Adds ~35,000 usernames, most of which are high-level. Takes only a couple of minutes to run.

### Step 2: Expand via Guild Memberships
```
python find_uuid_with_guild.py
```
For each username, checks their guild and extracts guildmates. This helps balance the dataset by adding mid/low-level players. May take up to 12 hours to fully finish running, but because of hypixel API limits, you can do 5000 requests per day. Used Python here for asynchronous functions which speed up the code by a lot. 

→ Turns all the usernames we have, and all their guild members to a UUID list. Expected to add 85000 UUID's.

---

## 📥 Data Collection from the usernames

Javascript is needed here for the usage of net worth calculation NPM package. 
Run the script:
```
node data_collection.js
```

This generates `player_data.csv`, which contains:
- Username
- Player Level
- Magical Power
- Net Worth

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

**Current Progress:**

UUID Collection: 🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩 **100%**

Data Collection: 🟩⬜⬜⬜⬜⬜⬜⬜⬜⬜ **12.26%**

**Current Data:**

![plot1](https://github.com/user-attachments/assets/c2d1c703-6b50-4d2e-908c-514acd72a395)

![plot2](https://github.com/user-attachments/assets/95217079-aa94-4b86-bcd7-7ddf7cf4d3cd)

![plot3](https://github.com/user-attachments/assets/dc11b58a-06d3-4672-8db2-c061793f9088)

---

## 📄 License and Credits

All data in this repository is free to use.

Special thanks to:
- SkyHelper-Networth --> https://github.com/Altpapier/SkyHelper-Networth
- Soopy API (For leaderboard data)
- Mojang API (Turning UUID's to usernames)
- Hypixel API (Guild members list, user and museum data)
