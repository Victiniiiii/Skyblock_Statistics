library(ggplot2)
library(gridExtra)
library(scales)
library(broom)

plotDataFromCSV <- function() {
    data <- read.csv("player_data.csv", stringsAsFactors = FALSE)    
    data$networth <- as.numeric(gsub("[^0-9.]", "", data$networth))
    
    y_fmt <- scale_y_continuous(
        breaks = scales::pretty_breaks(n = 10),
        labels = label_number(scale_cut = cut_short_scale()),
        expand = expansion(mult = c(0.02, 0.02))
    )
    
    x_fmt <- scale_x_continuous(
        breaks = scales::pretty_breaks(n = 10)
    )
    
    common_theme <- theme_minimal(base_size = 13) +
        theme(
            plot.title  = element_text(hjust = 0.5, face = "bold", color = "white"),
            axis.title  = element_text(face = "bold", color = "white"),
            axis.text   = element_text(color = "white"),
            panel.grid.major = element_line(color = "grey85"),
            panel.background = element_rect(fill = "black"),
            plot.background = element_rect(fill = "black")
        )

    lm1 <- lm(networth ~ magical_power, data = data)
    lm1_summary <- summary(lm1)
    lm1_coeffs <- tidy(lm1)

    p1 <- ggplot(data, aes(x = magical_power, y = networth)) +
        geom_point(alpha = 0.6, color = "#1f77b4") +
        geom_smooth(method = "lm", se = FALSE, color = "#1f77b4") +
        labs(
            title = paste("Magical Power vs Networth\nR^2 =", round(lm1_summary$r.squared, 2), 
                          "\nIntercept =", round(lm1_coeffs$estimate[1], 2),
                          "\nSlope =", round(lm1_coeffs$estimate[2], 2)),
            x = "Magical Power",
            y = "Networth (coins)"
        ) +
        x_fmt + y_fmt + common_theme

    lm2 <- lm(networth ~ level, data = data)
    lm2_summary <- summary(lm2)
    lm2_coeffs <- tidy(lm2)

    p2 <- ggplot(data, aes(x = level, y = networth)) +
        geom_point(alpha = 0.6, color = "#d62728") +
        geom_smooth(method = "lm", se = FALSE, color = "#d62728") +
        labs(
            title = paste("Level vs Networth\nR^2 =", round(lm2_summary$r.squared, 2),
                          "\nIntercept =", round(lm2_coeffs$estimate[1], 2),
                          "\nSlope =", round(lm2_coeffs$estimate[2], 2)),
            x = "Level",
            y = "Networth (coins)"
        ) +
        x_fmt + y_fmt + common_theme

    lm3 <- lm(level ~ magical_power, data = data)
    lm3_summary <- summary(lm3)
    lm3_coeffs <- tidy(lm3)

    p3 <- ggplot(data, aes(x = magical_power, y = level)) +
        geom_point(alpha = 0.6, color = "#2ca02c") +
        geom_smooth(method = "lm", se = FALSE, color = "#2ca02c") +
        labs(
            title = paste("Magical Power vs Level\nR^2 =", round(lm3_summary$r.squared, 2),
                          "\nIntercept =", round(lm3_coeffs$estimate[1], 2),
                          "\nSlope =", round(lm3_coeffs$estimate[2], 2)),
            x = "Magical Power",
            y = "Level"
        ) +
        x_fmt +
        scale_y_continuous(breaks = scales::pretty_breaks(n = 10)) +
        common_theme
    
    ggsave("plot1.png", p1, width = 20, height = 15, dpi = 300)
    ggsave("plot2.png", p2, width = 20, height = 15, dpi = 300)
    ggsave("plot3.png", p3, width = 20, height = 15, dpi = 300)
    
    grid.arrange(p1, p2, p3, ncol = 1)
}

plotDataFromCSV()
