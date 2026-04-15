# Render hexbin or 2D binned scatter.

source("R/visual/chart_utils.R")

render_hexbin <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("scatter"), config)
  method <- cfg$method %||% "hex"

  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$x_value, y = .data$y_value))
  if (identical(method, "hex") && requireNamespace("hexbin", quietly = TRUE)) {
    p <- p + ggplot2::stat_bin_hex() + ggplot2::scale_fill_viridis_c()
  } else {
    p <- p + ggplot2::geom_bin_2d() + ggplot2::scale_fill_viridis_c()
  }

  p <- apply_plot_labels(
    p,
    data = data,
    title = cfg$title %||% "Hexbin / 2D Density Scatter",
    subtitle = cfg$subtitle,
    x = unique(data$x_label)[1] %||% NULL,
    y = unique(data$y_label)[1] %||% NULL,
    side_note = cfg$caption_side_note,
    footer_note = cfg$caption_footer_note
  )
  p + (theme %||% visual_theme(base_size = cfg$base_size))
}
