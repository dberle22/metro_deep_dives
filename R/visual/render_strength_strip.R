# Render strength strip.

source("R/visual/chart_utils.R")

render_strength_strip <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("strength_strip"), config)
  ensure_columns(data, c("metric_label", "normalized_value"), chart_type = "strength_strip")

  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data$normalized_value, y = stats::reorder(.data$metric_label, .data$normalized_value))
  ) +
    ggplot2::geom_col(fill = cfg$base_color) +
    ggplot2::scale_x_continuous(limits = c(0, 100))

  p <- apply_plot_labels(
    p,
    data = data,
    title = cfg$title %||% "Strength Strip",
    subtitle = cfg$subtitle,
    x = cfg$x_label %||% "Percentile",
    y = NULL,
    side_note = cfg$caption_side_note,
    footer_note = cfg$caption_footer_note
  )

  p + (theme %||% visual_theme(base_size = cfg$base_size))
}
