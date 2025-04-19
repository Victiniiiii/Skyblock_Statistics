library(httr)
library(jsonlite)

API_KEY <- readLines("config.txt")[1]
NETWORTH_ENDPOINT <- "http://localhost:3000/networth"
STATE_FILE <- "state.json"
OUTPUT_FILE <- "player_data.csv"

loadState <- function() {
    if (file.exists(STATE_FILE)) {
        state <- fromJSON(STATE_FILE)
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
    write(toJSON(state, auto_unbox = TRUE, pretty = TRUE), STATE_FILE)
}

getProfileData <- function(uuid, retries = 1) {
    url <- paste0("https://api.hypixel.net/v2/skyblock/profiles?uuid=", uuid, "&key=", API_KEY)
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
            cat("⏳ Rate limited. Waiting", 5, "seconds... (Attempt", i, "/", retries, ")\n")
            Sys.sleep(5)
        } else {
            stop("❌ API error ", status)
        }
    }
    cat("❌ Failed after retries for UUID", uuid, "\n")
    return(NULL)
}

getMuseumData <- function(uuid, profileId) {
    url <- paste0("https://api.hypixel.net/v2/skyblock/museum?profile=", profileId, "&key=", API_KEY)
    res <- GET(url)

    if (status_code(res) != 200) stop("Museum API failed (status ", status_code(res), ")")

    data <- content(res, "parsed", type = "application/json")

    if (!isTRUE(data$success) || !is.list(data$members)) stop("Museum data missing")
    if (!(uuid %in% names(data$members))) stop("No museum entry for UUID")

    data$members[[uuid]]
}

calculateNetworth <- function(profileData, museumData, bankBalance) {
    res <- POST(
        NETWORTH_ENDPOINT,
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

collectDataToCSV <- function() {
    uuids <- trimws(readLines("uuids.txt"))
    uuids <- unique(uuids[uuids != ""])

    state <- loadState()
    processed <- state$processed_uuids
    current_index <- state$current_index
    total <- if (state$total == 0) length(uuids) else state$total

    if (file.exists(OUTPUT_FILE)) {
        data_for_csv <- read.csv(OUTPUT_FILE, stringsAsFactors = FALSE)
        processed <- unique(c(processed, data_for_csv$uuid))
    } else {
        data_for_csv <- data.frame(
            uuid          = character(0),
            magical_power = numeric(0),
            level         = numeric(0),
            networth      = numeric(0),
            stringsAsFactors = FALSE
        )
    }

    for (i in current_index:length(uuids)) {
        uuid <- uuids[i]

        cat(sprintf("\n📦 Progress: %d / %d\n", i, total))

        if (uuid %in% processed) {
            cat("⏭️ Skipping already processed UUID:", uuid, "\n")
            next
        }

        cat("👤 Processing UUID:", uuid, "\n")

        saveState(processed, i, total)

        prof <- NULL
        tryCatch({
            prof <- getProfileData(uuid)
        }, error = function(e) {
            cat("\t❌ Profile error:", conditionMessage(e), "\n")
        })

        if (is.null(prof)) {
            next
        }

        tryCatch({
            pd   <- prof$profileData
            bb   <- prof$bankBalance
            pid  <- prof$profileId
            md   <- getMuseumData(uuid, pid)

            mp  <- pd$accessory_bag_storage$highest_magical_power
            lvl <- pd$leveling$experience / 100
            nw  <- calculateNetworth(pd, md, bb)

            cat(
                "\t✅ Profile & museum loaded\n",
                "\t📈 Level:", lvl, "\n",
                "\t✨ Magical Power:", mp, "\n",
                "\t💰 Networth:", nw, "coins\n"
            )

            data_for_csv <- rbind(data_for_csv, data.frame(
                uuid          = uuid,
                magical_power = mp,
                level         = lvl,
                networth      = nw,
                stringsAsFactors = FALSE
            ))

            write.csv(data_for_csv, OUTPUT_FILE, row.names = FALSE)

            processed <- c(processed, uuid)
            saveState(processed, i + 1, total)

        }, error = function(e) {
            cat("\t❌ Error processing UUID:", uuid, "-", conditionMessage(e), "\n")
        })
    }

    cat("\n🎉 Data collection complete. Total:", nrow(data_for_csv), "entries.\n")
    saveState(processed, 1, total)
}

collectDataToCSV()
