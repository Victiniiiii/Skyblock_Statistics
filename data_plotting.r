plotDataFromCSV <- function() {
    data_for_plotting <- read.csv("player_data.csv")

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

plotDataFromCSV()
