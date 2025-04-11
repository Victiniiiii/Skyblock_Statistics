import aiohttp
import asyncio
import logging
from asyncio_throttle import Throttler

# Logging
logging.basicConfig(
    filename='guild_crawler.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger()

# Config
with open("config.txt", "r") as file:
    API_KEY = file.readline().strip()
HEADERS = {"User-Agent": "SkyBlockGuildCrawler/1.0"}

# Load players
with open("player_list.txt", "r") as f:
    existing_names = set(name.strip() for name in f if name.strip())
new_names = set()

# Track seen guilds to avoid duplicates
seen_guilds = set()

# Rate limits
hypixel_throttler = Throttler(rate_limit=2, period=1)     # 2 requests/sec
mojang_throttler  = Throttler(rate_limit=1, period=1)     # 1 request/sec

async def throttled_fetch(session, url, throttler):
    async with throttler:
        for attempt in range(1, 4):  # Retry up to 3 times
            try:
                async with session.get(url, headers=HEADERS) as resp:
                    if resp.status == 200:
                        return await resp.json()
                    else:
                        print(f"    ⚠️  [{attempt}/3] Bad status {resp.status} for {url}")
                        logger.warning(f"Bad status {resp.status} fetching {url}")
            except Exception as e:
                print(f"    ⚠️  [{attempt}/3] Exception fetching {url}: {e}")
                logger.warning(f"Exception fetching {url}: {e}")
            await asyncio.sleep(0.5)
    print(f"    ❌ Failed to fetch {url} after 3 attempts")
    logger.error(f"Failed to fetch {url} after retries")
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

async def uuid_to_username(session, uuid):
    url = f"https://sessionserver.mojang.com/session/minecraft/profile/{uuid}"
    data = await throttled_fetch(session, url, mojang_throttler)
    return data.get("name") if data else None

async def process_player(session, name, sem):
    async with sem:
        print(f"\n🔎 Processing player: {name}")
        logger.info(f"Start processing {name}")
        try:
            print(f"    • Fetching UUID for {name}…")
            uuid = await get_uuid(session, name)
            if not uuid:
                print(f"    ⚠️  No UUID found for {name}")
                logger.warning(f"UUID not found for {name}")
                return

            print(f"    • UUID for {name}: {uuid}")
            print(f"    • Fetching guild members for {name}…")
            guild_id, members = await get_guild_members(session, uuid)

            if not guild_id:
                logger.info(f"No guild found for {name}")
                return

            if guild_id in seen_guilds:
                print(f"    ⚠️ Guild {guild_id} already processed. Skipping.")
                logger.info(f"Skipped guild {guild_id} for {name}")
                return

            seen_guilds.add(guild_id)
            print(f"    • {len(members)} members in guild")

            usernames = []
            for member_uuid in members:
                print(f"        – Resolving username for {member_uuid}…")
                u = await uuid_to_username(session, member_uuid)
                if u:
                    usernames.append(u)

            for username in usernames:
                if username not in existing_names and username not in new_names:
                    new_names.add(username)
                    print(f"    ➕ New player found: {username}")
                    logger.info(f"Found new player: {username}")

        except Exception as e:
            print(f"    ❌ Error processing {name}: {e}")
            logger.error(f"Error processing {name}: {e}")
        finally:
            print(f"✅ Done with {name}")
            logger.info(f"Finished processing {name}")

async def main():
    sem = asyncio.Semaphore(5)

    async with aiohttp.ClientSession() as session:
        tasks = [
            asyncio.create_task(process_player(session, name, sem))
            for name in existing_names
        ]
        await asyncio.gather(*tasks)

    with open("new_players_found.txt", "w") as f:
        for name in sorted(new_names):
            f.write(name + "\n")

    print(f"\n🎉 All done! Found {len(new_names)} new players.")
    logger.info(f"Done! Found {len(new_names)} new players.")

if __name__ == "__main__":
    asyncio.run(main())
