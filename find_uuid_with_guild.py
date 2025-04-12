import aiohttp
import asyncio
import logging
import os
import json
from asyncio_throttle import Throttler

STATE_FILE = "state.json"

logging.basicConfig(
    filename='guild_crawler.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger()

with open("config.txt", "r") as file:
    API_KEY = file.readline().strip()
HEADERS = {"User-Agent": "SkyBlockGuildCrawler/1.0"}

with open("player_list.txt", "r") as f:
    player_list = [name.strip() for name in f if name.strip()]

if os.path.exists(STATE_FILE):
    with open(STATE_FILE, "r") as f:
        state = json.load(f)
    seen_guilds = set(state["seen_guilds"])
    all_uuids = set(state["all_uuids"])
    progress_counter = state["progress_counter"]
else:
    seen_guilds = set()
    all_uuids = set()
    progress_counter = 0

total_players = len(player_list)
error_429_counter = 0
progress_lock = asyncio.Lock()

# Throttlers
hypixel_throttler = Throttler(rate_limit=2, period=1)
mojang_throttler = Throttler(rate_limit=1, period=1)

def save_state():
    with open(STATE_FILE, "w") as f:
        json.dump({
            "progress_counter": progress_counter,
            "seen_guilds": list(seen_guilds),
            "all_uuids": list(all_uuids)
        }, f)

async def throttled_fetch(session, url, throttler):
    global error_429_counter
    async with throttler:
        for attempt in range(1, 1001):
            try:
                async with session.get(url, headers=HEADERS) as resp:
                    if resp.status == 200:
                        error_429_counter = 0
                        return await resp.json()
                    elif resp.status == 429:
                        error_429_counter += 1
                        logger.warning(f"429 Rate limited on {url} [{error_429_counter}]")
                        print(f"    🔁 429 Rate limited [{error_429_counter}/50] on {url}")

                        if error_429_counter >= 50:
                            print("\n🛑 Hit 50 consecutive 429s. Pausing script.")
                            logger.error("Paused due to 50 consecutive 429 errors.")
                            save_state()
                            exit(1)
                    else:
                        logger.warning(f"{resp.status} error on {url}")
                        return None
            except Exception as e:
                logger.warning(f"Exception on {url}: {e}")
                return None
            await asyncio.sleep(0.5)
    return None

async def get_uuid(session, name):
    url = f"https://api.mojang.com/users/profiles/minecraft/{name}"
    data = await throttled_fetch(session, url, mojang_throttler)
    return data.get("id") if data else None

async def get_guild_members(session, uuid):
    url = f"https://api.hypixel.net/guild?player={uuid}&key={API_KEY}"
    data = await throttled_fetch(session, url, hypixel_throttler)
    if data and data.get("guild"):
        guild_id = data["guild"]["_id"]
        members = [m["uuid"] for m in data["guild"]["members"]]
        return guild_id, members
    return None, []

async def process_player(session, name, sem, player_index):
    global progress_counter
    async with sem:
        print(f"\n🔎 [{player_index + 1}/{total_players}] {name}")
        logger.info(f"Processing {name}")

        try:
            uuid = await get_uuid(session, name)
            if not uuid:
                print(f"    ⚠️ No UUID for {name}")
                return

            all_uuids.add(uuid)
            guild_id, members = await get_guild_members(session, uuid)

            if not guild_id:
                print(f"    ⚠️ No guild for {name}")
                return

            if guild_id in seen_guilds:
                print(f"    ⏭️ Guild already processed: {guild_id}")
                return

            seen_guilds.add(guild_id)

            for member_uuid in members:
                all_uuids.add(member_uuid)
                print(f"        ➕ {member_uuid}")

        except Exception as e:
            print(f"    ❌ Error processing {name}: {e}")
            logger.error(f"Error on {name}: {e}")
        finally:
            async with progress_lock:
                progress_counter += 1
                save_state()
                print(f"✅ {name} done [{progress_counter}/{total_players}]")

async def main():
    sem = asyncio.Semaphore(5)

    names_to_process = player_list[progress_counter:]

    async with aiohttp.ClientSession() as session:
        tasks = [
            asyncio.create_task(process_player(session, name, sem, i + progress_counter))
            for i, name in enumerate(names_to_process)
        ]
        await asyncio.gather(*tasks)

    with open("uuids.txt", "w") as f:
        for uuid in sorted(all_uuids):
            f.write(uuid + "\n")

    save_state()
    print(f"\n🎉 Done! {len(all_uuids)} UUIDs saved.")
    logger.info(f"Completed script. {len(all_uuids)} UUIDs collected.")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n⏸️ Interrupted manually. Saving progress...")
        save_state()
        logger.warning("Interrupted manually.")
