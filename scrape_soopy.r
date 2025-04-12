library(httr)
library(jsonlite)

fields <- c(
    "networth", "catacombsXp", "catacombsLevel", "skillAvg",
    "skillAvgOver60", "totalSlayer", "weight",
    "classAverage", "sbLvl"
)

# Create a temporary vector to hold all usernames before writing
all_usernames <- c()

for (field in fields) {
    cat("Fetching for field:", field, "\n")

    for (page in 1:100) {
        url <- paste0("https://api.soopy.dev/lb/", field, "/", page)
        response <- GET(url)

        if (status_code(response) == 200) {
            json_data <- content(response, as = "text", encoding = "UTF-8")
            parsed <- fromJSON(json_data)

            if (!is.null(parsed$data) && is.data.frame(parsed$data)) {
                all_usernames <- c(all_usernames, parsed$data$username)
            }
        } else {
            cat("❌ Failed to fetch", field, "on page:", page, "\n")
        }
    }

    cat("✅ Fetched data for field:", field, "\n\n")
}

existing_usernames <- if (file.exists("player_list.txt")) {
    readLines("player_list.txt")
} else {
    character()
}

# Combine and remove duplicates
final_usernames <- unique(c(existing_usernames, all_usernames))
writeLines(final_usernames, "player_list.txt")
cat("🎉 Saved", length(final_usernames), "unique usernames to player_list.txt\n")
