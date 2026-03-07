# Shared visual standards helpers for chart rendering

library(ggplot2)
library(scales)

visual_theme <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      legend.background = element_rect(fill = "white", color = NA),
      legend.key = element_rect(fill = "white", color = NA)
    )
}

format_percent <- function(accuracy = 0.1) {
  scales::label_percent(accuracy = accuracy)
}

format_dollar <- function(scale_cut = scales::cut_short_scale()) {
  scales::label_dollar(scale_cut = scale_cut)
}

format_number <- function(scale_cut = scales::cut_short_scale()) {
  scales::label_number(scale_cut = scale_cut)
}

build_source_caption <- function(source, vintage) {
  paste0("Source: ", source, " | Vintage: ", vintage)
}

build_chart_notes <- function(source = NULL,
                              vintage = NULL,
                              side_note = NULL,
                              footer_note = NULL) {
  parts <- c()
  if (!is.null(source) && nzchar(source)) {
    parts <- c(parts, paste0("Source: ", source))
  }
  if (!is.null(vintage) && nzchar(vintage)) {
    parts <- c(parts, paste0("Vintage: ", vintage))
  }
  if (!is.null(side_note) && nzchar(side_note)) {
    parts <- c(parts, paste0("Note: ", side_note))
  }
  if (!is.null(footer_note) && nzchar(footer_note)) {
    parts <- c(parts, paste0("Footer: ", footer_note))
  }
  paste(parts, collapse = " | ")
}

# Standard scatter styling defaults shared across chart implementations.
scatter_style_defaults <- list(
  point_alpha = 0.7,
  palette = "viridis",
  base_color = "#2C7FB8",
  highlight_color = "#D73027",
  trend_line_linetype = "dashed",
  trend_line_alpha = 0.7,
  trend_line_color = "grey35",
  size_range = c(2, 10),
  size_breaks = c(1000, 10000, 100000, 1000000),
  label_size = 3,
  label_outline_size = 0.2
)
