# Render highlight-context map or fallback panel.

source("visual_library/shared/chart_utils.R")

render_highlight_context_map <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("map"), config)
  if ("geometry" %in% names(data) && requireNamespace("sf", quietly = TRUE)) {
    p <- ggplot2::ggplot(data) +
      ggplot2::geom_sf(fill = "grey92", color = "white", linewidth = 0.1) +
      ggplot2::geom_sf(data = data[data$highlight_flag %in% TRUE, , drop = FALSE], fill = cfg$highlight_color, color = "black", linewidth = 0.3)
    p <- apply_plot_labels(p, data = data, title = cfg$title %||% "Highlight + Context Map", subtitle = cfg$subtitle)
    return(p + (theme %||% visual_map_theme(base_size = cfg$base_size)))
  }

  render_placeholder_panel(
    data = data,
    chart_type = "highlight_context_map",
    title = cfg$title %||% "Highlight + Context Map Scaffold",
    subtitle = cfg$subtitle,
    detail_lines = c("Geometry-backed rendering will activate when geometry is supplied.")
  )
}
