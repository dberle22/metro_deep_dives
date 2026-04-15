# Render choropleth map or fallback summary panel.

source("visual_library/shared/chart_utils.R")

render_choropleth <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("map"), config)

  if ("geometry" %in% names(data) && requireNamespace("sf", quietly = TRUE)) {
    p <- ggplot2::ggplot(data) +
      ggplot2::geom_sf(ggplot2::aes(fill = .data$metric_value), color = "white", linewidth = 0.1) +
      ggplot2::scale_fill_viridis_c(na.value = cfg$na_fill)
    p <- apply_plot_labels(
      p,
      data = data,
      title = cfg$title %||% default_chart_title("choropleth", unique(data$metric_label)[1] %||% NULL),
      subtitle = cfg$subtitle,
      side_note = cfg$caption_side_note,
      footer_note = cfg$caption_footer_note
    )
    return(p + (theme %||% visual_map_theme(base_size = cfg$base_size)))
  }

  render_placeholder_panel(
    data = data,
    chart_type = "choropleth",
    title = cfg$title %||% "Choropleth Scaffold",
    subtitle = cfg$subtitle,
    detail_lines = c("Geometry column or sf package not available in this render context.")
  )
}
