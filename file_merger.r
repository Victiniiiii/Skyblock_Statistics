fields <- c("networth", "catacombsXp", "catacombsLevel", "skillAvg", 
            "skillAvgOver60", "totalSlayer", "weight", 
            "classAverage", "sbLvl")

field_files <- paste0("soopylist", fields, ".txt")

read_names_from_file <- function(file_path) {
    if (!file.exists(file_path)) return(character(0))
    lines <- readLines(file_path, warn = FALSE)
    trimws(lines)
}

merge_and_sort_names <- function(files) {
    all_names <- unlist(lapply(files, read_names_from_file))
    sorted_unique_names <- sort(unique(all_names))
    return(sorted_unique_names)
}

save_names_to_file <- function(names, file_path) {
    writeLines(names, con = file_path)
}

all_files <- c("output.txt", "player_list.txt", field_files)

sorted_names <- merge_and_sort_names(all_files)
save_names_to_file(sorted_names, "player_list.txt")

cat("The merged and fully sorted names have been saved to player_list.txt\n")
