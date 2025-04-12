library(httr)
library(jsonlite)

fields <- c("networth", "catacombsXp", "catacombsLevel", "skillAvg", 
            "skillAvgOver60", "totalSlayer", "weight", 
            "classAverage", "sbLvl")

for (field in fields) {
    usernames <- c()
    
    cat("Fetching for field:", field, "\n")
    
    for (page in 1:100) {
        url <- paste0("https://api.soopy.dev/lb/", field, "/", page)
        response <- GET(url)
        
        if (status_code(response) == 200) {
            json_data <- content(response, as = "text", encoding = "UTF-8")
            parsed <- fromJSON(json_data)
            
            if (!is.null(parsed$data) && is.data.frame(parsed$data)) {
                usernames <- c(usernames, parsed$data$username)
            }
        } else {
            cat("Failed to fetch", field, "on page:", page, "\n")
        }
    }
    
    filename <- paste0("soopylist", field, ".txt")
    writeLines(usernames, filename)
    cat("✅ Saved", length(usernames), "usernames to", filename, "\n\n")
}
