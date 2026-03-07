# Render line chart from prepared line data.
render_line <- function(data,
                        title = NULL,
                        subtitle = NULL,
                        y_label = NULL,
                        color_mode = c("geo_name", "highlight_flag"),
                        facet_by = NULL,
                        show_points = TRUE,
                        add_benchmark = FALSE) {
  color_mode <- match.arg(color_mode)
  stopifnot(is.data.frame(data))

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required.")
  }

  y_var <- if ("plot_value" %in% names(data)) "plot_value" else "metric_value"

  color_var <- if (color_mode == "highlight_flag" && "highlight_flag" %in% names(data)) {
    data$highlight_flag <- ifelse(isTRUE(data$highlight_flag), "highlight", "peer")
    "highlight_flag"
  } else {
    "geo_name"
  }

  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data$period, y = .data[[y_var]], color = .data[[color_var]])
  ) +
    ggplot2::geom_line(linewidth = 1)

  if (isTRUE(show_points)) {
    p <- p + ggplot2::geom_point(size = 1.8)
  }

  if (!is.null(facet_by) && facet_by %in% names(data)) {
    p <- p + ggplot2::facet_wrap(stats::as.formula(paste("~", facet_by)), scales = "free_y")
  }

  if (isTRUE(add_benchmark) && "benchmark_value" %in% names(data)) {
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

  cap <- paste0("Source: ", unique(data$source)[1], " | Vintage: ", unique(data$vintage)[1])

  p <- p +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      x = NULL,
      y = y_label,
      caption = cap,
      color = NULL
    )

  if (exists("visual_theme", mode = "function")) {
    p <- p + visual_theme(base_size = 12)
  } else {
    p <- p + ggplot2::theme_minimal(base_size = 12)
  }

  p
}
