# --------------------[ DEPENDENCIES ]--------------------
install.packages(c(
    "httr",
    "jsonlite",
    "progress"
))
library(httr)
library(jsonlite)
library(progress)

# --------------------[ CONFIGURATION ]--------------------
CONFIG <- list(
    api_key = readLines("config.txt")[1],
    networth_endpoint = "http://localhost:3000/networth",
    state_file = "state.json",
    output_file = "player_data.csv",
    uuid_file = "uuids.txt"
)

# --------------------[ STATE HANDLING ]--------------------
loadState <- function() {
    if (file.exists(CONFIG$state_file)) {
        state <- fromJSON(CONFIG$state_file)
        if (is.null(state$processed_uuids)) state$processed_uuids <- character()
        if (is.null(state$current_index)) state$current_index <- 1
        if (is.null(state$total)) state$total <- 0
        return(state)
    } else {
        return(list(
            processed_uuids = character(),
            current_index = 1,
            total = 0
        ))
    }
}

saveState <- function(processed_uuids, current_index, total) {
    state <- list(
        processed_uuids = processed_uuids,
        current_index = current_index,
        total = total
    )
    write(toJSON(state, auto_unbox = TRUE, pretty = TRUE), CONFIG$state_file)
}

# --------------------[ API FUNCTIONS ]--------------------
getProfileData <- function(uuid, retries = 3) {
    url <- sprintf("https://api.hypixel.net/v2/skyblock/profiles?uuid=%s&key=%s", uuid, CONFIG$api_key)
    for (i in 1:retries) {
        res <- GET(url)
        status <- status_code(res)

        if (status == 200) {
            data <- content(res, "parsed", type = "application/json")
            if (!isTRUE(data$success) || length(data$profiles) == 0) stop("No profile data")
            sel <- Filter(function(p) isTRUE(p$selected), data$profiles)
            if (length(sel) == 0) stop("No selected profile")
            p <- sel[[1]]
            return(list(
                profileData = p$members[[uuid]],
                bankBalance = if (!is.null(p$banking)) p$banking$balance else 0,
                profileId   = p$profile_id
            ))
        } else if (status == 429) {
            delay <- 2 * i
            cat(sprintf("⏳ Rate limited. Waiting %d seconds... (Attempt %d/%d)\n", delay, i, retries))
            Sys.sleep(delay)
        } else {
            stop("❌ API error ", status)
        }
    }
    return(NULL)
}

getMuseumData <- function(uuid, profileId) {
    url <- sprintf("https://api.hypixel.net/v2/skyblock/museum?profile=%s&key=%s", profileId, CONFIG$api_key)
    res <- GET(url)
    if (status_code(res) != 200) stop("Museum API failed (status ", status_code(res), ")")

    data <- content(res, "parsed", type = "application/json")
    if (!isTRUE(data$success) || !is.list(data$members)) stop("Museum data missing")
    if (!(uuid %in% names(data$members))) stop("No museum entry for UUID")

    data$members[[uuid]]
}

calculateNetworth <- function(profileData, museumData, bankBalance) {
    res <- POST(
        CONFIG$networth_endpoint,
        body = toJSON(list(
            profileData = profileData,
            museumData = museumData,
            bankBalance = bankBalance
        ), auto_unbox = TRUE),
        encode = "json",
        content_type_json()
    )

    if (status_code(res) != 200) stop("Networth API returned ", status_code(res), ": ", content(res, "text"))
    result <- content(res, "parsed", type = "application/json")

    raw_nw <- result$networth
    nw_num <- as.numeric(raw_nw)
    if (is.na(nw_num)) stop("Invalid networth value: ", raw_nw)

    formatC(nw_num, format = "f", digits = 2, big.mark = ",")
}

# --------------------[ DATA HELPERS ]--------------------
initializeDataFrame <- function() {
    if (file.exists(CONFIG$output_file)) {
        return(read.csv(CONFIG$output_file, stringsAsFactors = FALSE))
    } else {
        return(data.frame(
            uuid = character(),
            magical_power = numeric(),
            level = numeric(),
            networth = character(),
            stringsAsFactors = FALSE
        ))
    }
}

appendRecord <- function(df, uuid, mp, lvl, nw) {
    df[nrow(df) + 1, ] <- list(uuid = uuid, magical_power = mp, level = lvl, networth = nw)
    return(df)
}

safeExtract <- function(obj, path, default = NA) {
    tryCatch(
        {
            val <- eval(parse(text = paste0("obj$", path)))
            if (is.null(val)) default else val
        },
        error = function(e) default
    )
}

formatDuration <- function(seconds) {
    days <- seconds %/% 86400
    hours <- (seconds %% 86400) %/% 3600
    minutes <- (seconds %% 3600) %/% 60
    secs <- seconds %% 60
    sprintf("%dd %02dh %02dm %02ds", days, hours, minutes, secs)
}

# --------------------[ MAIN LOOP ]--------------------
collectDataToCSV <- function() {
    uuids <- unique(trimws(readLines(CONFIG$uuid_file)))
    uuids <- uuids[uuids != ""]

    state <- loadState()
    processed <- state$processed_uuids
    current_index <- state$current_index
    total <- if (state$total == 0) length(uuids) else state$total
    data_for_csv <- initializeDataFrame()

    start_time <- Sys.time()
    remaining <- length(uuids) - current_index + 1

    for (i in current_index:length(uuids)) {
        uuid <- uuids[i]
        elapsed <- as.numeric(Sys.time() - start_time, units = "secs")
        est_total <- (elapsed / (i - current_index + 1)) * remaining
        eta <- formatDuration(round(est_total))

        cat(sprintf("\n📦 Progress: %d / %d | ETA: %s\n", i, total, eta))

        if (uuid %in% processed) {
            next
        }

        saveState(processed, i, total)
        prof <- NULL

        tryCatch(
            {
                prof <- getProfileData(uuid)
            },
            error = function(e) {
                cat("❌ Profile error for", uuid, ":", conditionMessage(e), "\n")
            }
        )

        if (is.null(prof)) next

        tryCatch(
            {
                pd <- prof$profileData
                bb <- prof$bankBalance
                pid <- prof$profileId
                md <- getMuseumData(uuid, pid)

                mp <- safeExtract(pd, "accessory_bag_storage$highest_magical_power", 0)
                lvl <- safeExtract(pd, "leveling$experience", 0) / 100
                nw <- calculateNetworth(pd, md, bb)

                cat(sprintf("✅ %s — Level: %.2f | MP: %d | NW: %s\n", uuid, lvl, mp, nw))

                data_for_csv <- appendRecord(data_for_csv, uuid, mp, lvl, nw)
                write.csv(data_for_csv, CONFIG$output_file, row.names = FALSE)

                processed <- c(processed, uuid)
                saveState(processed, i + 1, total)
            },
            error = function(e) {
                cat("❌ Error processing", uuid, ":", conditionMessage(e), "\n")
            }
        )
    }

    cat("\n🎉 Data collection complete. Total entries:", nrow(data_for_csv), "\n")
    saveState(processed, 1, total)
}

# --------------------[ EXECUTION ]--------------------
collectDataToCSV()
