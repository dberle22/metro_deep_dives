# Render bivariate choropleth or fallback panel.

source("visual_library/shared/chart_utils.R")

render_bivariate_choropleth <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("map"), config)
  if ("geometry" %in% names(data) && requireNamespace("sf", quietly = TRUE)) {
    palette <- c(
      "1-1" = "#e8e8e8", "1-2" = "#ace4e4", "1-3" = "#5ac8c8",
      "2-1" = "#dfb0d6", "2-2" = "#a5add3", "2-3" = "#5698b9",
      "3-1" = "#be64ac", "3-2" = "#8c62aa", "3-3" = "#3b4994"
    )
    p <- ggplot2::ggplot(data) +
      ggplot2::geom_sf(ggplot2::aes(fill = .data$bivar_class), color = "white", linewidth = 0.1) +
      ggplot2::scale_fill_manual(values = palette, na.value = cfg$na_fill)
    p <- apply_plot_labels(p, data = data, title = cfg$title %||% "Bivariate Choropleth", subtitle = cfg$subtitle)
    return(p + (theme %||% visual_map_theme(base_size = cfg$base_size)))
  }

  render_placeholder_panel(data, "bivariate_choropleth", cfg$title %||% "Bivariate Choropleth Scaffold", cfg$subtitle)
}
