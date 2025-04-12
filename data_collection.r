library(httr)
library(jsonlite)

API_KEY <- readLines("config.txt")[1]
NETWORTH_ENDPOINT <- "http://localhost:3000/networth"

# Function to fetch profile data with retry logic for rate-limiting (status 429)
getProfileData <- function(uuid, retries = 3, delay = 2) {
    url <- paste0("https://api.hypixel.net/v2/skyblock/profiles?uuid=", uuid, "&key=", API_KEY)
    
    for (i in 1:retries) {
        res <- GET(url)
        status <- status_code(res)
        
        if (status == 200) {
            data <- content(res, "parsed", type = "application/json")
            if (!isTRUE(data$success) || length(data$profiles) == 0) {
                stop("No profile data")
            }
            sel <- Filter(function(p) isTRUE(p$selected), data$profiles)
            if (length(sel) == 0) stop("No selected profile")
            p <- sel[[1]]
            return(list(
                profileData = p$members[[uuid]],
                bankBalance = if (!is.null(p$banking)) p$banking$balance else 0,
                profileId   = p$profile_id
            ))
        } else if (status == 429) {  # 429 -> Too many requests
            cat("⏳ Hypixel API rate-limited. Waiting", delay, "seconds... (Attempt", i, "/", retries, ")\n")
            Sys.sleep(delay)
            delay <- delay * 2  # Double the delay for next retry
        } else {
            stop("❌ Hypixel API failed for UUID ", uuid, " (status ", status, ")")
        }
    }

    # If retries exceeded, return NULL and log it, don't skip.
    cat("❌ Failed after retries for UUID ", uuid, "\n")
    return(NULL)
}

getMuseumData <- function(uuid, profileId) {
    url <- paste0("https://api.hypixel.net/v2/skyblock/museum?profile=", profileId, "&key=", API_KEY)
    res <- GET(url)

    if (status_code(res) != 200) {
        stop("Museum API failed (status ", status_code(res), ")")
    }

    data <- content(res, "parsed", type = "application/json")

    if (!isTRUE(data$success) || !is.list(data$members)) {
        stop("Museum data missing")
    }

    if (!(uuid %in% names(data$members))) {
        stop("No museum entry for this UUID")
    }

    data$members[[uuid]]
}

calculateNetworth <- function(profileData, museumData, bankBalance) {
    res <- POST(
        NETWORTH_ENDPOINT,
        body = toJSON(list(
            profileData = profileData,
            museumData  = museumData,
            bankBalance = bankBalance
        ), auto_unbox = TRUE),
        encode = "json",
        content_type_json()
    )

    if (status_code(res) != 200) {
        stop("Networth API returned ", status_code(res), ": ",
             content(res, "text", encoding = "UTF-8"))
    }

    result <- content(res, "parsed", type = "application/json")
    raw_nw <- result$networth
    nw_num <- as.numeric(raw_nw)
    if (is.na(nw_num)) stop("Invalid networth value: ", raw_nw)
    formatC(nw_num, format = "f", digits = 2, big.mark = ",")
}

collectDataToCSV <- function() {
    uuids <- trimws(readLines("uuids.txt"))
    uuids <- unique(uuids[uuids != ""])  # Remove blank lines and duplicates

    data_for_csv <- data.frame(
        uuid          = character(0),
        magical_power = numeric(0),
        level         = numeric(0),
        networth      = numeric(0),
        stringsAsFactors = FALSE
    )

    failed_uuids <- c()

    for (uuid in uuids) {
        cat("\n👤 Processing UUID:", uuid, "\n")

        prof <- NULL
        tryCatch({
            prof <- getProfileData(uuid)
        }, error = function(e) {
            cat("\t❌ Error during profile retrieval:", conditionMessage(e), "– Continuing to next UUID.\n")
        })

        if (is.null(prof)) {
            failed_uuids <- c(failed_uuids, uuid)
            cat("\t❌ Skipping UUID:", uuid, "due to failure\n")
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
                "\t✅ Profile & bank data retrieved\n",
                "\t✅ Museum data retrieved\n",
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

        }, error = function(e) {
            cat("\t❌ Error during processing for UUID:", uuid, "-", conditionMessage(e), "– Continuing to next UUID.\n")
        })
    }

    if (length(failed_uuids) > 0) {
        cat("\n🚧 Retrying failed UUIDs...\n")
        for (uuid in failed_uuids) {
            cat("\n👤 Retrying UUID:", uuid, "\n")

            prof <- NULL
            tryCatch({
                prof <- getProfileData(uuid)
            }, error = function(e) {
                cat("\t❌ Error during profile retrieval:", conditionMessage(e), "– Skipping UUID.\n")
            })

            if (is.null(prof)) {
                cat("\t❌ Failed to retrieve data for UUID:", uuid, "after retries.\n")
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
                    "\t✅ Profile & bank data retrieved\n",
                    "\t✅ Museum data retrieved\n",
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

            }, error = function(e) {
                cat("\t❌ Error during processing for UUID:", uuid, "-", conditionMessage(e), "– Skipping UUID.\n")
            })
        }
    }

    write.csv(data_for_csv, "player_data.csv", row.names = FALSE)
}

collectDataToCSV()
