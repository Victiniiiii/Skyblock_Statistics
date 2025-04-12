import aiohttp
import asyncio
import logging
from asyncio_throttle import Throttler

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
    existing_names = list(name.strip() for name in f if name.strip())
total_players = len(existing_names)

seen_guilds = set()
all_uuids = set()

# Throttle limits, Mojang and Hypixel both have 1 request per second limit.
hypixel_throttler = Throttler(rate_limit=1, period=1)
mojang_throttler = Throttler(rate_limit=1, period=1)

progress_counter = 0
progress_lock = asyncio.Lock()

async def throttled_fetch(session, url, throttler):
    async with throttler:
        for attempt in range(1, 1001):
            try:
                async with session.get(url, headers=HEADERS) as resp:
                    if resp.status == 200:
                        return await resp.json()
                    elif resp.status == 429:
                        print(f"    🔁 [{attempt}/100] Rate limited on {url}, retrying…")
                        logger.warning(f"429 Rate limited on {url}")
                    else:
                        logger.warning(f"{resp.status} error for {url}, not retrying.")
                        return None
            except Exception as e:
                print(f"    ⚠️  Exception on attempt {attempt} for {url}: {e}")
                logger.warning(f"Exception fetching {url}: {e}")
                return None
            await asyncio.sleep(0.5)
    print(f"    ❌ Gave up after 100 retries for {url}")
    logger.error(f"Gave up after 100 retries for {url}")
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
        print(f"\n🔎 [{player_index + 1}/{total_players}] Processing player: {name}")
        logger.info(f"Start processing {name} ({player_index + 1}/{total_players})")

        try:
            uuid = await get_uuid(session, name)
            if not uuid:
                print(f"    ⚠️  No UUID for {name}")
                logger.warning(f"UUID not found for {name}")
                return

            print(f"    • UUID for {name}: {uuid}")
            all_uuids.add(uuid)

            guild_id, members = await get_guild_members(session, uuid)
            if not guild_id:
                print(f"    ⚠️  No guild found for {name}")
                logger.info(f"No guild found for {name}")
                return

            if guild_id in seen_guilds:
                print(f"    ⚠️ Guild {guild_id} already processed. Skipping.")
                logger.info(f"Skipped duplicate guild {guild_id}")
                return

            seen_guilds.add(guild_id)
            print(f"    • {len(members)} guild members found")

            for member_uuid in members:
                all_uuids.add(member_uuid)
                print(f"        ➕ Added UUID: {member_uuid}")

        except Exception as e:
            print(f"    ❌ Error processing {name}: {e}")
            logger.error(f"Error processing {name}: {e}")
        finally:
            async with progress_lock:
                progress_counter += 1
                print(f"✅ Done with {name} [{progress_counter}/{total_players} done]")
                logger.info(f"Finished {name} [{progress_counter}/{total_players}]")

async def main():
    sem = asyncio.Semaphore(5)

    async with aiohttp.ClientSession() as session:
        tasks = [
            asyncio.create_task(process_player(session, name, sem, i))
            for i, name in enumerate(existing_names)
        ]
        await asyncio.gather(*tasks)

    with open("uuids.txt", "w") as f:
        for uuid in sorted(all_uuids):
            f.write(uuid + "\n")

    print(f"\n🎉 Done! Collected {len(all_uuids)} unique UUIDs.")
    logger.info(f"Script complete — {len(all_uuids)} UUIDs collected.")

if __name__ == "__main__":
    asyncio.run(main())
