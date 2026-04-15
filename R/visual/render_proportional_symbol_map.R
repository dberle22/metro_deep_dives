# Render proportional symbol map or fallback panel.

source("R/visual/chart_utils.R")

render_proportional_symbol_map <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("map"), config)
  if (all(c("lon", "lat") %in% names(data))) {
    p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$lon, y = .data$lat, size = .data$size_value)) +
      ggplot2::geom_point(alpha = cfg$point_alpha, color = cfg$base_color) +
      ggplot2::scale_size_continuous(range = cfg$size_range)
    p <- apply_plot_labels(p, data = data, title = cfg$title %||% "Proportional Symbol Map", subtitle = cfg$subtitle)
    return(p + (theme %||% visual_map_theme(base_size = cfg$base_size)))
  }
  render_placeholder_panel(data, "proportional_symbol_map", cfg$title %||% "Proportional Symbol Map Scaffold", cfg$subtitle)
}
