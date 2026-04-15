# Render age pyramid.

source("visual_library/shared/chart_utils.R")

render_age_pyramid <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("age_pyramid"), config)
  ensure_columns(data, c("age_bin", "plot_value", "sex"), chart_type = "age_pyramid")
  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$plot_value, y = .data$age_bin, fill = .data$sex)) +
    ggplot2::geom_col() +
    ggplot2::scale_x_continuous(labels = scales::label_percent())
  p <- apply_plot_labels(p, data = data, title = cfg$title %||% "Age Pyramid", subtitle = cfg$subtitle, x = NULL, y = NULL)
  p + (theme %||% visual_theme(base_size = cfg$base_size))
}
