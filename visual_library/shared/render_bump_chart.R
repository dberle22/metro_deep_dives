# Render bump chart.

source("visual_library/shared/chart_utils.R")

render_bump_chart <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(chart_default_config("line"), config)
  ensure_columns(data, c("period", "rank", "geo_name"), chart_type = "bump_chart")
  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$period, y = .data$rank, color = .data$geo_name, group = .data$geo_id)) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::scale_y_reverse(labels = format_rank())
  p <- apply_plot_labels(p, data = data, title = cfg$title %||% "Bump Chart", subtitle = cfg$subtitle, x = NULL, y = "Rank")
  p + (theme %||% visual_theme(base_size = cfg$base_size))
}
