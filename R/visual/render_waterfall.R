# Render waterfall chart.

source("R/visual/chart_utils.R")

render_waterfall <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("waterfall"), config)
  ensure_columns(data, c("component_label", "plot_value", "cumulative_start", "cumulative_end"), chart_type = "waterfall")
  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$component_label)) +
    ggplot2::geom_rect(
      ggplot2::aes(
        xmin = seq_along(component_label) - 0.4,
        xmax = seq_along(component_label) + 0.4,
        ymin = pmin(.data$cumulative_start, .data$cumulative_end),
        ymax = pmax(.data$cumulative_start, .data$cumulative_end),
        fill = .data$plot_value >= 0
      ),
      color = "white"
    ) +
    ggplot2::scale_fill_manual(values = c("TRUE" = cfg$positive_fill, "FALSE" = cfg$negative_fill), guide = "none")
  p <- apply_plot_labels(p, data = data, title = cfg$title %||% "Waterfall Chart", subtitle = cfg$subtitle, x = NULL, y = NULL)
  p + (theme %||% visual_theme(base_size = cfg$base_size)) + ggplot2::coord_flip()
}
