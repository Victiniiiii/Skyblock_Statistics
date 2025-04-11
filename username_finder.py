from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time

chrome_options = Options()
# chrome_options.add_argument("--headless")

driver = webdriver.Chrome(options=chrome_options)

base_url = "https://hypixel.net/forums/skyblock-general-discussion.157/"
usernames = set()
visited_threads = set()

wait = WebDriverWait(driver, 10)

def visit_thread_and_collect_usernames(thread_url):
    driver.get(thread_url)
    time.sleep(2)
    
    elements = wait.until(EC.presence_of_all_elements_located((By.CSS_SELECTOR, "span[itemprop='name']")))

    for el in elements:
        name = el.text.strip()
        if name:
            print(name)
            usernames.add(name)

    try:
        pagination = driver.find_element(By.CSS_SELECTOR, "div.pageNav-main")
        pages = pagination.find_elements(By.CSS_SELECTOR, "a.pageNavPage")

        if pages:
            for page in range(2, len(pages) + 1):
                next_page_url = thread_url.rstrip('/') + f"/page-{page}"
                print(f"Going to page {page} of {thread_url}...")
                visit_thread_and_collect_usernames(next_page_url)
    except Exception as e:
        print(f"No pagination found for {thread_url}. Error: {e}")

for page in range(1, 68):
    print(f"Page {page}...")
    driver.get(f"{base_url}page-{page}")
    time.sleep(2)

    thread_links = wait.until(EC.presence_of_all_elements_located((By.CSS_SELECTOR, "a[href^='/threads/']")))
    thread_urls = set()

    for link in thread_links:
        href = link.get_attribute("href")
        if href and href.startswith("/threads/"):
            thread_urls.add("https://hypixel.net" + href)
        elif href and href.startswith("https://hypixel.net/threads/"):
            thread_urls.add(href)

    for thread_url in thread_urls:
        if thread_url in visited_threads:
            continue

        visited_threads.add(thread_url)
        try:
            visit_thread_and_collect_usernames(thread_url)

        except Exception as e:
            print(f"Error navigating to {thread_url}: {e}")
            continue

driver.quit()

with open("output.txt", "w", encoding="utf-8") as f:
    for name in sorted(usernames):
        f.write(name + "\n")

print(f"\nDone. {len(usernames)} unique usernames saved.")
