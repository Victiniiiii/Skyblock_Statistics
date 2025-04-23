library(httr)
library(jsonlite)

uuid_file <- "uuids.txt"
player_file <- "player_list.txt"
state_file <- "sync_state.json"

file.copy(uuid_file, paste0(uuid_file, ".bak"), overwrite = TRUE)
file.copy(player_file, paste0(player_file, ".bak"), overwrite = TRUE)

uuid_list <- unique(trimws(readLines(uuid_file)))
player_list <- unique(trimws(readLines(player_file)))

if (file.exists(state_file)) {
    state <- fromJSON(state_file, simplifyVector = TRUE)
} else {
    state <- list(
        valid_uuids = character(0),
        valid_players = character(0),
        checked_uuids = character(0),
        checked_players = character(0),
        uuid_to_name_cache = list(),
        name_to_uuid_cache = list()
    )
}

uuid_to_name_cache <- state$uuid_to_name_cache
name_to_uuid_cache <- state$name_to_uuid_cache

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
            break
        }
    }
    return(NULL)
}

is_valid_uuid <- function(uuid) {
    grepl("^[0-9a-fA-F]{32}$", uuid)
}

get_username_from_uuid <- function(uuid) {
    if (!is_valid_uuid(uuid)) {
        return(NA)
    }
    if (!is.null(uuid_to_name_cache[[uuid]])) {
        return(uuid_to_name_cache[[uuid]])
    }

    url <- paste0("https://sessionserver.mojang.com/session/minecraft/profile/", uuid)
    result <- safe_get(url)
    name <- if (!is.null(result) && !is.null(result$name)) result$name else NA

    uuid_to_name_cache[[uuid]] <<- name
    return(name)
}

get_uuid_from_username <- function(username) {
    if (!is.null(name_to_uuid_cache[[username]])) {
        return(name_to_uuid_cache[[username]])
    }

    url <- paste0("https://api.mojang.com/users/profiles/minecraft/", username)
    result <- safe_get(url)
    id <- if (!is.null(result) && !is.null(result$id)) result$id else NA

    name_to_uuid_cache[[username]] <<- id
    return(id)
}

save_state <- function() {
    state$valid_uuids <- valid_uuids
    state$valid_players <- valid_players
    state$checked_uuids <- checked_uuids
    state$checked_players <- checked_players
    state$uuid_to_name_cache <- uuid_to_name_cache
    state$name_to_uuid_cache <- name_to_uuid_cache
    write(toJSON(state, pretty = TRUE, auto_unbox = TRUE), file = state_file)
}

# ========== UUID Checking ========== #
valid_uuids <- state$valid_uuids
checked_uuids <- state$checked_uuids

for (uuid in setdiff(uuid_list, checked_uuids)) {
    username <- get_username_from_uuid(uuid)
    if (!is.na(username)) {
        valid_uuids <- unique(c(valid_uuids, uuid))
        if (!(username %in% player_list)) {
            cat(sprintf("Adding missing username: %s\n", username))
            player_list <- unique(c(player_list, username))
        }
    } else {
        cat(sprintf("Removed invalid UUID: %s\n", uuid))
    }
    checked_uuids <- unique(c(checked_uuids, uuid))
    save_state()
}

# ========== Username Checking ========== #
valid_players <- state$valid_players
checked_players <- state$checked_players

for (username in setdiff(player_list, checked_players)) {
    uuid <- get_uuid_from_username(username)
    if (!is.na(uuid)) {
        valid_players <- unique(c(valid_players, username))
        if (!(uuid %in% valid_uuids)) {
            cat(sprintf("Adding missing UUID for username: %s\n", username))
            valid_uuids <- unique(c(valid_uuids, uuid))
        }
    } else {
        cat(sprintf("Removed invalid username: %s\n", username))
    }
    checked_players <- unique(c(checked_players, username))
    save_state()
}

writeLines(sort(unique(valid_uuids)), uuid_file)
writeLines(sort(unique(valid_players)), player_file)
save_state()
cat("Sync complete! Files updated and backups saved.\n")
