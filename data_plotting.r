install.packages(c("ggplot2", "gridExtra", "scales", "broom", "dplyr", "GGally"))
library(ggplot2)
library(gridExtra)
library(scales)
library(broom)
library(dplyr)
library(GGally)

remove_outliers_df <- function(df, cols) {
    for (col in cols) {
        qnt <- quantile(df[[col]], probs = c(0.25, 0.75), na.rm = TRUE)
        iqr <- qnt[2] - qnt[1]
        lower <- qnt[1] - 1.5 * iqr
        upper <- qnt[2] + 1.5 * iqr
        df <- df %>% filter(df[[col]] >= lower & df[[col]] <= upper)
    }
    return(df)
}

custom_y_scale <- function() {
    scale_y_continuous(
        breaks = pretty_breaks(n = 10),
        labels = label_number(scale_cut = cut_short_scale()),
        expand = expansion(mult = c(0.02, 0.02)),
        limits = c(0, NA)
    )
}

custom_x_scale <- function() {
    scale_x_continuous(breaks = pretty_breaks(n = 10))
}

common_theme <- theme_minimal(base_size = 13) +
    theme(
        plot.title = element_text(hjust = 0.5, face = "bold", color = "#79827b"),
        axis.title = element_text(face = "bold", color = "#79827b"),
        axis.text = element_text(color = "#79827b"),
        panel.grid.major = element_line(color = "#4a524c"),
        panel.background = element_rect(fill = "black"),
        plot.background = element_rect(fill = "black")
    )

clean_data <- function(df) {
    df$networth <- as.numeric(gsub("[^0-9.]", "", df$networth))
    return(df)
}

regression_and_plot <- function(data, xvar, yvar, xlab, ylab, color) {
    fmla <- as.formula(paste(yvar, "~", xvar))
    model <- lm(fmla, data = data)
    summary_model <- summary(model)
    coeffs <- tidy(model)

    r2 <- round(summary_model$r.squared, 3)
    intercept <- round(coeffs$estimate[1], 3)
    slope <- round(coeffs$estimate[2], 3)

    cat(sprintf("\n--- Regression: %s vs %s ---\n", yvar, xvar))
    cat(sprintf("R^2       : %.3f\n", r2))
    cat(sprintf("Intercept : %.3f\n", intercept))
    cat(sprintf("Slope     : %.3f\n", slope))

    p <- ggplot(data, aes_string(x = xvar, y = yvar)) +
        geom_point(alpha = 0.6, color = color) +
        geom_smooth(method = "loess", se = FALSE, color = color) +
        labs(title = paste(xlab, "vs", ylab), x = xlab, y = ylab) +
        custom_x_scale() +
        custom_y_scale() +
        common_theme

    return(p)
}

plotDataFromCSV <- function() {
    data <- read.csv("player_data.csv", stringsAsFactors = FALSE)
    data <- clean_data(data)

    data <- data %>%
        filter(!is.na(magical_power), !is.na(networth), !is.na(level)) %>%
        filter(networth >= 0)

    data <- remove_outliers_df(data, c("networth", "magical_power", "level"))

    cat("\n--- Descriptive Stats ---\n")
    print(summary(data))
    cat("\nStandard Deviations:\n")
    print(sapply(data[, c("networth", "magical_power", "level")], sd, na.rm = TRUE))
    cat("\nVariances:\n")
    print(sapply(data[, c("networth", "magical_power", "level")], var, na.rm = TRUE))

    sink("regression_stats.txt")
    p1 <- regression_and_plot(data, "magical_power", "networth", "Magical Power", "Networth (coins)", "#1f77b4")
    p2 <- regression_and_plot(data, "level", "networth", "Level", "Networth (coins)", "#d62728")
    p3 <- regression_and_plot(data, "magical_power", "level", "Magical Power", "Level", "#2ca02c")
    sink()

    plots <- list(p1, p2, p3)
    for (i in seq_along(plots)) {
        ggsave(paste0("plot", i, ".png"), plots[[i]], width = 20, height = 15, dpi = 300)
    }

    ggpairs_plot <- ggpairs(data[, c("networth", "magical_power", "level")])
    ggsave("pairwise_plot.png", ggpairs_plot, width = 15, height = 15, dpi = 300)

    grid.arrange(p1, p2, p3, ncol = 1)
}

plotDataFromCSV()
