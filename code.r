install.packages(c("httr", "jsonlite", "ggplot2", "gridExtra"))
library(httr)
library(jsonlite)
library(ggplot2)
library(gridExtra)

API_KEY <- readLines("config.txt")[1]
NETWORTH_ENDPOINT <- "http://localhost:3000/networth"

# This function inputs minecraft UUID and outputs minecraft usernames.
getUUID <- function(username, retries = 3, delay = 2) {
    url <- paste0("https://api.mojang.com/users/profiles/minecraft/", username)
    
    for (i in 1:retries) {
        response <- GET(url)
        status <- status_code(response)
        
        if (status == 200) {
            data <- content(response, "parsed", type = "application/json")
            return(data$id)
        } else if (status == 429) { # 429 --> Too many requests
            cat("⏳ Mojang API rate-limited. Waiting", delay, "seconds... (Try", i, "/", retries, ")\n")
            Sys.sleep(delay)
            delay <- delay * 2  # Doubles the last delay
        } else {
            stop("❌ Mojang API failed for ", username, " (status ", status, ")")
        }
    }

    stop("❌ Mojang API still failing after retries for ", username)
}

getProfileData <- function(uuid) {
    url <- paste0("https://api.hypixel.net/v2/skyblock/profiles?uuid=", uuid, "&key=", API_KEY)
    res <- GET(url)

    if (status_code(res) != 200) {
        stop("SkyBlock Profile API failed (status ", status_code(res), ")")
    }

    data <- content(res, "parsed", type = "application/json")

    if (!isTRUE(data$success) || length(data$profiles) == 0) {
        stop("No profile data")
    }

    sel <- Filter(function(p) isTRUE(p$selected), data$profiles)
    if (length(sel) == 0) stop("No selected profile")
    p <- sel[[1]]

    list(
        profileData = p$members[[uuid]],
        bankBalance = if (!is.null(p$banking)) p$banking$balance else 0,
        profileId   = p$profile_id
    )
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

collectData <- function() {
    users <- trimws(readLines("player_list.txt"))
    users <- unique(users[users != ""]) # dedupe & drop blanks

    data_for_plotting <- data.frame(
        magical_power = numeric(0),
        level = numeric(0),
        networth = numeric(0)
    )

    for (username in users) {
        cat("\n👤 Player:", username, "\n")

        tryCatch({
            uuid <- getUUID(username)
            prof <- getProfileData(uuid)
            pd   <- prof$profileData
            bb   <- prof$bankBalance
            pid  <- prof$profileId
            md <- getMuseumData(uuid, pid)
            mp <- pd$accessory_bag_storage$highest_magical_power
            lvl_exp <- pd$leveling$experience
            lvl <- lvl_exp / 100
            nw <- calculateNetworth(pd, md, bb)

            cat(
                "\t✅ UUID:", uuid, "\n",
                "\t✅ Profile & bank retrieved\n",
                "\t✅ Museum data retrieved\n",
                "\t📈 Level:", lvl, "\n",
                "\t✨ Magical Power:", mp, "\n",
                "\t💰 Net worth:", nw, "coins\n"
            )

            data_for_plotting <- rbind(data_for_plotting, data.frame(
                magical_power = mp,
                level = lvl,
                networth = as.numeric(nw)
            ))

        }, error = function(e) {
            cat("\t❌ Excluding", username, "–", conditionMessage(e), "\n")
        })
    }

    return(data_for_plotting)
}

plotData <- function(data_for_plotting) {
    p1 <- ggplot(data_for_plotting, aes(x = magical_power, y = networth)) +
        geom_point() + geom_smooth(method = "lm", color = "blue", se = FALSE) +
        labs(title = "Magical Power vs Networth", x = "Magical Power", y = "Networth (coins)")

    p2 <- ggplot(data_for_plotting, aes(x = level, y = networth)) +
        geom_point() + geom_smooth(method = "lm", color = "red", se = FALSE) +
        labs(title = "Level vs Networth", x = "Level", y = "Networth (coins)")

    p3 <- ggplot(data_for_plotting, aes(x = magical_power, y = level)) +
        geom_point() + geom_smooth(method = "lm", color = "green", se = FALSE) +
        labs(title = "Magical Power vs Level", x = "Magical Power", y = "Level")

    grid.arrange(p1, p2, p3, ncol = 1)
}

processAndPlot <- function() {
    data_for_plotting <- collectData()
    plotData(data_for_plotting)
}

processAndPlot()
