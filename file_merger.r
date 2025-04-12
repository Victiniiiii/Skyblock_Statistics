log_lines <- readLines("guild_crawler.log", warn = FALSE)
found_lines <- grep("Found new player:", log_lines, value = TRUE)
new_usernames <- sub(".*Found new player: ", "", found_lines)

fields <- c("networth", "catacombsXp", "catacombsLevel", "skillAvg", 
            "skillAvgOver60", "totalSlayer", "weight", 
            "classAverage", "sbLvl")
field_files <- paste0("soopylist", fields, ".txt")
all_files <- c("output.txt", "player_list.txt", field_files)

read_names_from_file <- function(file_path) {
    if (!file.exists(file_path)) return(character(0))
    trimws(readLines(file_path, warn = FALSE))
}

existing_names <- unlist(lapply(all_files, read_names_from_file))
all_usernames <- c(existing_names, new_usernames)
unique_sorted_usernames <- sort(unique(all_usernames))

writeLines(unique_sorted_usernames, "player_list.txt")
cat("Merged and saved", length(unique_sorted_usernames), "unique usernames to player_list.txt\n")
