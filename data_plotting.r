library(ggplot2)
library(gridExtra)
library(scales)

plotDataFromCSV <- function() {
    data <- read.csv("player_data.csv", stringsAsFactors = FALSE)    
    data$networth <- as.numeric(gsub("[^0-9.]", "", data$networth))
    
    y_fmt <- scale_y_continuous(
        labels = label_number(scale_cut = cut_short_scale()),
        expand = expansion(mult = c(0.02, 0.02))
    )
    
    common_theme <- theme_minimal(base_size = 13) +
        theme(
        plot.title  = element_text(hjust = 0.5, face = "bold"),
        axis.title  = element_text(face = "bold"),
        panel.grid.major = element_line(color = "grey85")
        )
    
    p1 <- ggplot(data, aes(x = magical_power, y = networth)) +
        geom_point(alpha = 0.6, color = "#1f77b4") +
        geom_smooth(method = "lm", se = FALSE, color = "#1f77b4") +
        labs(
        title = "Magical Power vs Networth",
        x = "Magical Power",
        y = "Networth (coins)"
        ) +
        y_fmt + common_theme
    
    p2 <- ggplot(data, aes(x = level, y = networth)) +
        geom_point(alpha = 0.6, color = "#d62728") +
        geom_smooth(method = "lm", se = FALSE, color = "#d62728") +
        labs(
        title = "Level vs Networth",
        x = "Level",
        y = "Networth (coins)"
        ) +
        y_fmt + common_theme
    
    p3 <- ggplot(data, aes(x = magical_power, y = level)) +
        geom_point(alpha = 0.6, color = "#2ca02c") +
        geom_smooth(method = "lm", se = FALSE, color = "#2ca02c") +
        labs(
        title = "Magical Power vs Level",
        x = "Magical Power",
        y = "Level"
        ) +
        common_theme
    
    grid.arrange(p1, p2, p3, ncol = 1)
}

plotDataFromCSV()
