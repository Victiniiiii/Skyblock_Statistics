install.packages(c(
    "ggplot2",
    "gridExtra",
    "scales",
    "broom",
    "dplyr"
))
library(ggplot2)
library(gridExtra)
library(scales)
library(broom)
library(dplyr)

remove_outliers <- function(x) {
    qnt <- quantile(x, probs = c(0.25, 0.75), na.rm = TRUE)
    iqr <- qnt[2] - qnt[1]
    x >= (qnt[1] - 1.5 * iqr) & x <= (qnt[2] + 1.5 * iqr)
}

plotDataFromCSV <- function() {
    data <- read.csv("player_data.csv", stringsAsFactors = FALSE)
    data$networth <- as.numeric(gsub("[^0-9.]", "", data$networth))

    data <- data %>%
        filter(!is.na(magical_power), !is.na(networth), !is.na(level)) %>%
        filter(networth >= 0) %>%
        filter(remove_outliers(networth) & remove_outliers(magical_power) & remove_outliers(level))


    print("--- Descriptive Stats ---")
    print(summary(data))
    print("Standard Deviations:")
    print(sapply(data[, c("networth", "magical_power", "level")], sd, na.rm = TRUE))
    print("Variances:")
    print(sapply(data[, c("networth", "magical_power", "level")], var, na.rm = TRUE))

    y_fmt <- scale_y_continuous(
        breaks = scales::pretty_breaks(n = 10),
        labels = label_number(scale_cut = cut_short_scale()),
        expand = expansion(mult = c(0.02, 0.02)),
        limits = c(0, NA)
    )


    x_fmt <- scale_x_continuous(
        breaks = scales::pretty_breaks(n = 10)
    )

    common_theme <- theme_minimal(base_size = 13) +
        theme(
            plot.title = element_text(hjust = 0.5, face = "bold", color = "white"),
            axis.title = element_text(face = "bold", color = "white"),
            axis.text = element_text(color = "white"),
            panel.grid.major = element_line(color = "grey85"),
            panel.background = element_rect(fill = "black"),
            plot.background = element_rect(fill = "black")
        )

    regression_and_plot <- function(xvar, yvar, xlab, ylab, color) {
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
            x_fmt +
            y_fmt +
            common_theme

        return(p)
    }

    p1 <- regression_and_plot("magical_power", "networth", "Magical Power", "Networth (coins)", "#1f77b4")
    p2 <- regression_and_plot("level", "networth", "Level", "Networth (coins)", "#d62728")
    p3 <- regression_and_plot("magical_power", "level", "Magical Power", "Level", "#2ca02c")

    ggsave("plot1.png", p1, width = 20, height = 15, dpi = 300)
    ggsave("plot2.png", p2, width = 20, height = 15, dpi = 300)
    ggsave("plot3.png", p3, width = 20, height = 15, dpi = 300)

    grid.arrange(p1, p2, p3, ncol = 1)
}

plotDataFromCSV()
