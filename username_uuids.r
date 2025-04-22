library(httr)
library(jsonlite)

uuid_file <- "uuids.txt"
player_file <- "player_list.txt"
file.copy(uuid_file, paste0(uuid_file, ".bak"), overwrite = TRUE)
file.copy(player_file, paste0(player_file, ".bak"), overwrite = TRUE)
uuid_list <- unique(trimws(readLines(uuid_file)))
player_list <- unique(trimws(readLines(player_file)))

uuid_to_name_cache <- list()
name_to_uuid_cache <- list()

safe_get <- function(url, max_tries = 5) {
  for (i in 1:max_tries) {
    res <- tryCatch(GET(url), error = function(e) NULL)
    if (is.null(res)) next
    
    if (status_code(res) == 200) {
      return(content(res, as = "parsed", type = "application/json"))
    } else if (status_code(res) == 429) {
      wait_time <- 2 * i
      cat(sprintf("Rate limited. Waiting %d seconds...\n", wait_time))
      Sys.sleep(wait_time)
    } else {
      break  # Non-recoverable error
    }
  }
  return(NULL)
}

is_valid_uuid <- function(uuid) {
  grepl("^[0-9a-fA-F]{32}$", uuid)
}

get_username_from_uuid <- function(uuid) {
  if (!is_valid_uuid(uuid)) return(NA)
  if (!is.null(uuid_to_name_cache[[uuid]])) return(uuid_to_name_cache[[uuid]])
  
  url <- paste0("https://sessionserver.mojang.com/session/minecraft/profile/", uuid)
  result <- safe_get(url)
  name <- if (!is.null(result) && !is.null(result$name)) result$name else NA
  
  uuid_to_name_cache[[uuid]] <- name
  return(name)
}

get_uuid_from_username <- function(username) {
  if (!is.null(name_to_uuid_cache[[username]])) return(name_to_uuid_cache[[username]])
  
  url <- paste0("https://api.mojang.com/users/profiles/minecraft/", username)
  result <- safe_get(url)
  id <- if (!is.null(result) && !is.null(result$id)) result$id else NA
  
  name_to_uuid_cache[[username]] <- id
  return(id)
}

# ========== UUID Checking ========== #
valid_uuids <- c()
for (uuid in uuid_list) {
  username <- get_username_from_uuid(uuid)
  if (!is.na(username)) {
    valid_uuids <- c(valid_uuids, uuid)
    if (!(username %in% player_list)) {
      cat(sprintf("Adding missing username: %s\n", username))
      player_list <- c(player_list, username)
    }
  } else {
    cat(sprintf("Removed invalid UUID: %s\n", uuid))
  }
}

# ========== Username Checking ========== #
valid_players <- c()
for (username in player_list) {
  uuid <- get_uuid_from_username(username)
  if (!is.na(uuid)) {
    valid_players <- c(valid_players, username)
    if (!(uuid %in% valid_uuids)) {
      cat(sprintf("Adding missing UUID for username: %s\n", username))
      valid_uuids <- c(valid_uuids, uuid)
    }
  } else {
    cat(sprintf("Removed invalid username: %s\n", username))
  }
}

# ========== Save Results ========== #
writeLines(sort(unique(valid_uuids)), uuid_file)
writeLines(sort(unique(valid_players)), player_file)
cat("Sync complete! Files updated and backups saved.\n")
