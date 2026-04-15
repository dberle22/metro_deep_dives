# Render correlation heatmap.

source("visual_library/shared/chart_utils.R")

render_correlation_heatmap <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("correlation_heatmap"), config)
  ensure_columns(data, c("metric_x", "metric_y", "correlation"), chart_type = "correlation_heatmap")

  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$metric_x, y = .data$metric_y, fill = .data$correlation)) +
    ggplot2::geom_tile(color = "white") +
    ggplot2::scale_fill_gradient2(low = cfg$diverging_low, mid = cfg$diverging_mid, high = cfg$diverging_high, midpoint = 0, limits = c(-1, 1)) +
    ggplot2::coord_equal()

  p <- apply_plot_labels(
    p,
    data = data,
    title = cfg$title %||% "Correlation Heatmap",
    subtitle = cfg$subtitle,
    x = NULL,
    y = NULL
  )
  p + (theme %||% visual_theme(base_size = cfg$base_size))
}
