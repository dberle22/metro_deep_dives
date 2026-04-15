# Shared visual standards helpers for chart rendering.

library(ggplot2)
library(scales)

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

visual_theme <- function(base_size = 12, base_family = "sans") {
  theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      legend.background = element_rect(fill = "white", color = NA),
      legend.key = element_rect(fill = "white", color = NA),
      panel.grid.minor = element_blank(),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      axis.title.x = element_text(margin = margin(t = 10)),
      axis.title.y = element_text(margin = margin(r = 10))
    )
}

visual_map_theme <- function(base_size = 12, base_family = "sans") {
  visual_theme(base_size = base_size, base_family = base_family) +
    theme(
      axis.text = element_blank(),
      axis.title = element_blank(),
      axis.ticks = element_blank(),
      panel.grid = element_blank()
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

format_rank <- function() {
  function(x) paste0("#", scales::label_number(accuracy = 1)(x))
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

chart_default_config <- function(chart_type = NULL) {
  base <- list(
    base_size = 12,
    palette = "viridis",
    point_alpha = 0.75,
    line_alpha = 0.9,
    base_color = "#2C7FB8",
    highlight_color = "#D73027",
    neutral_color = "grey70",
    positive_fill = "#1B9E77",
    negative_fill = "#D95F02",
    diverging_low = "#2166AC",
    diverging_mid = "#F7F7F7",
    diverging_high = "#B2182B",
    size_range = c(2, 10),
    label_size = 3,
    caption_side_note = NULL,
    caption_footer_note = NULL
  )

  chart_specific <- switch(
    chart_type %||% "",
    scatter = list(trend_line_linetype = "dashed", trend_line_alpha = 0.7, trend_line_color = "grey35"),
    line = list(show_points = TRUE),
    bar = list(flip = TRUE),
    heatmap_table = list(tile_color = "white"),
    map = list(na_fill = "grey90"),
    list()
  )

  utils::modifyList(base, chart_specific)
}

merge_chart_config <- function(defaults, config = NULL) {
  if (is.null(config)) {
    return(defaults)
  }
  utils::modifyList(defaults, config)
}

apply_plot_labels <- function(plot,
                              data = NULL,
                              title = NULL,
                              subtitle = NULL,
                              x = NULL,
                              y = NULL,
                              caption = NULL,
                              side_note = NULL,
                              footer_note = NULL) {
  if (is.null(caption) && !is.null(data) && all(c("source", "vintage") %in% names(data))) {
    caption <- build_chart_notes(
      source = unique(stats::na.omit(data$source))[1] %||% NULL,
      vintage = unique(stats::na.omit(data$vintage))[1] %||% NULL,
      side_note = side_note,
      footer_note = footer_note
    )
  }

  plot + ggplot2::labs(
    title = title,
    subtitle = subtitle,
    x = x,
    y = y,
    caption = caption
  )
}

render_placeholder_panel <- function(data,
                                     chart_type,
                                     title,
                                     subtitle = NULL,
                                     detail_lines = NULL) {
  detail_lines <- detail_lines %||% c()
  lines <- c(
    paste("Chart type:", chart_type),
    paste("Rows:", nrow(data)),
    detail_lines
  )

  p <- ggplot2::ggplot(data.frame(x = 1, y = 1), ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_label(
      label = paste(lines, collapse = "\n"),
      size = 4,
      label.size = 0.2
    ) +
    ggplot2::xlim(0.5, 1.5) +
    ggplot2::ylim(0.5, 1.5)

  p <- apply_plot_labels(
    plot = p,
    title = title,
    subtitle = subtitle,
    data = data
  )

  p +
    visual_theme() +
    ggplot2::theme(
      axis.text = ggplot2::element_blank(),
      axis.title = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank()
    )
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
