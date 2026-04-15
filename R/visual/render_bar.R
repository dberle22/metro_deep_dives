# Render ranked horizontal bar charts.

source("R/visual/chart_utils.R")

bar_value_labeler <- function(values, label_style = "number", accuracy = NULL) {
  if (identical(label_style, "percent")) {
    fmt <- scales::label_number(accuracy = accuracy %||% 0.1, suffix = "%")
    return(fmt(values))
  }
  if (identical(label_style, "dollar")) {
    fmt <- scales::label_dollar(accuracy = accuracy %||% 1)
    return(fmt(values))
  }
  fmt <- scales::label_number(
    accuracy = accuracy %||% 0.1,
    scale_cut = scales::cut_short_scale()
  )
  fmt(values)
}

render_bar <- function(data, config = list(), theme = NULL) {
  cfg <- merge_chart_config(
    merge_chart_config(
      chart_default_config("bar"),
      list(
        title = NULL,
        subtitle = NULL,
        bar_variant = "ranked_horizontal",
        show_labels = TRUE,
        label_style = "number",
        label_accuracy = NULL,
        highlight_legend = FALSE,
        bar_width = 0.72
      )
    ),
    config
  )

  ensure_columns(data, c("geo_name", "metric_value"), chart_type = "bar")
  value_var <- if ("plot_value" %in% names(data)) "plot_value" else "metric_value"
  plot_data <- data
  plot_data <- plot_data[order(plot_data[[value_var]], decreasing = TRUE), , drop = FALSE]
  plot_data$geo_name <- factor(plot_data$geo_name, levels = rev(plot_data$geo_name))

  fill_scale <- NULL
  if ("highlight_flag" %in% names(plot_data)) {
    plot_data$fill_group <- ifelse(plot_data$highlight_flag, "Target", "Comparison")
    fill_scale <- ggplot2::scale_fill_manual(
      values = c("Comparison" = cfg$neutral_color, "Target" = cfg$highlight_color),
      guide = if (isTRUE(cfg$highlight_legend)) "legend" else "none"
    )
  } else if ("series" %in% names(plot_data)) {
    plot_data$fill_group <- plot_data$series
  } else {
    plot_data$fill_group <- "Default"
    fill_scale <- ggplot2::scale_fill_manual(values = c("Default" = cfg$base_color), guide = "none")
  }

  p <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data$geo_name, y = .data[[value_var]], fill = .data$fill_group)
  ) +
    ggplot2::geom_col(width = cfg$bar_width, show.legend = isTRUE(cfg$highlight_legend))

  if (isTRUE(cfg$show_labels)) {
    plot_data$label_value <- bar_value_labeler(
      plot_data[[value_var]],
      label_style = cfg$label_style,
      accuracy = cfg$label_accuracy
    )
    p <- p +
      ggplot2::geom_text(
        data = plot_data,
        ggplot2::aes(label = .data$label_value),
        hjust = -0.1,
        size = 3.3,
        show.legend = FALSE
      )
  }

  if (!is.null(fill_scale)) {
    p <- p + fill_scale
  }

  if (isTRUE(cfg$flip %||% TRUE)) {
    p <- p + ggplot2::coord_flip()
  }

  upper_bound <- max(plot_data[[value_var]], na.rm = TRUE)
  if (is.finite(upper_bound) && upper_bound > 0) {
    p <- p + ggplot2::scale_y_continuous(
      expand = ggplot2::expansion(mult = c(0.02, 0.14))
    )
  }

  p <- apply_plot_labels(
    plot = p,
    data = plot_data,
    title = cfg$title %||% default_chart_title("bar", unique(plot_data$metric_label)[1] %||% NULL),
    subtitle = cfg$subtitle,
    x = NULL,
    y = cfg$y_label %||% unique(plot_data$metric_label)[1] %||% NULL,
    side_note = cfg$caption_side_note,
    footer_note = cfg$caption_footer_note
  )

  p + (theme %||% visual_theme(base_size = cfg$base_size)) +
    ggplot2::theme(
      axis.title.y = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank()
    )
}
