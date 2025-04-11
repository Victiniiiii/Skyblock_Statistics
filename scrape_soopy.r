install.packages(c("httr", "jsonlite"))
library(httr)
library(jsonlite)

usernames <- c()

for (page in 1:100) {
    url <- paste0("https://api.soopy.dev/lb/networth/", page)
    response <- GET(url)
    
    if (status_code(response) == 200) {
        json_data <- content(response, as = "text", encoding = "UTF-8")
        parsed <- fromJSON(json_data)
        
        if (!is.null(parsed$data) && is.data.frame(parsed$data)) {
            usernames <- c(usernames, parsed$data$username)
            cat(usernames)
        }
    } else {
        cat("Failed to fetch page:", page, "\n")
    }
}

writeLines(usernames, "usernames.txt")
cat("Done! Saved", length(usernames), "usernames to usernames.txt\n")

