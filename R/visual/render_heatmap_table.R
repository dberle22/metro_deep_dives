# Render heatmap table.

source("R/visual/chart_utils.R")

render_heatmap_table <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("heatmap_table"), config)
  ensure_columns(data, c("geo_name", "column_label", "normalized_value"), chart_type = "heatmap_table")
  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$column_label, y = .data$geo_name, fill = .data$normalized_value)) +
    ggplot2::geom_tile(color = cfg$tile_color) +
    ggplot2::scale_fill_viridis_c(limits = c(0, 100))
  p <- apply_plot_labels(p, data = data, title = cfg$title %||% "Heatmap Table", subtitle = cfg$subtitle, x = NULL, y = NULL)
  p + (theme %||% visual_theme(base_size = cfg$base_size))
}
