# Render line chart from prepared line data.

source("visual_library/shared/chart_utils.R")

render_line <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(
    chart_default_config("line"),
    config
  )
  ensure_columns(data, c("period", "geo_name"), chart_type = "line")

  y_var <- if ("plot_value" %in% names(data)) "plot_value" else "metric_value"
  color_mode <- cfg$color_mode %||% "geo_name"
  facet_by <- cfg$facet_by %||% NULL
  show_points <- isTRUE(cfg$show_points %||% TRUE)
  add_benchmark <- isTRUE(cfg$add_benchmark %||% FALSE)

  color_var <- if (identical(color_mode, "highlight_flag") && "highlight_flag" %in% names(data)) {
    data$highlight_flag <- ifelse(coerce_logical_column(data$highlight_flag), "highlight", "peer")
    "highlight_flag"
  } else {
    "geo_name"
  }

  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data$period, y = .data[[y_var]], color = .data[[color_var]], group = .data$geo_name)
  ) +
    ggplot2::geom_line(linewidth = 1, alpha = cfg$line_alpha)

  if (show_points) {
    p <- p + ggplot2::geom_point(size = 1.8, alpha = cfg$point_alpha)
  }

  if (!is.null(facet_by) && facet_by %in% names(data)) {
    p <- p + ggplot2::facet_wrap(stats::as.formula(paste("~", facet_by)), scales = "free_y")
  }

  if (add_benchmark && "benchmark_value" %in% names(data)) {
    bench <- data[!is.na(data$benchmark_value), c("period", "benchmark_value")]
    if (nrow(bench) > 0) {
      bench <- stats::aggregate(benchmark_value ~ period, data = bench, FUN = mean)
      p <- p + ggplot2::geom_line(
        data = bench,
        ggplot2::aes(x = period, y = benchmark_value),
        inherit.aes = FALSE,
        linewidth = 1,
        linetype = "dashed",
        color = "black"
      )
    }
  }

  p <- apply_plot_labels(
    plot = p,
    data = data,
    title = cfg$title %||% default_chart_title("line", unique(data$metric_label)[1] %||% NULL),
    subtitle = cfg$subtitle %||% NULL,
    x = NULL,
    y = cfg$y_label %||% unique(data$metric_label)[1] %||% NULL,
    side_note = cfg$caption_side_note,
    footer_note = cfg$caption_footer_note
  )

  p + (theme %||% visual_theme(base_size = cfg$base_size))
}
