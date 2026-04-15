# Render slopegraph.

source("R/visual/chart_utils.R")

render_slopegraph <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("line"), config)
  ensure_columns(data, c("geo_id", "geo_name", "period", "metric_value"), chart_type = "slopegraph")
  p <- ggplot2::ggplot(data, ggplot2::aes(x = factor(.data$period), y = .data$metric_value, group = .data$geo_id, color = .data$geo_name)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::geom_point(size = 2)
  p <- apply_plot_labels(
    p,
    data = data,
    title = cfg$title %||% "Slopegraph",
    subtitle = cfg$subtitle,
    x = NULL,
    y = unique(data$metric_label)[1] %||% NULL
  )
  p + (theme %||% visual_theme(base_size = cfg$base_size))
}
