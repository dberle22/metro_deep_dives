# Shared helpers used across visual library prep/render functions.

source("visual_library/shared/standards.R")

ensure_columns <- function(data, required, chart_type = "chart") {
  stopifnot(is.data.frame(data))
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "%s is missing required columns: %s",
        chart_type,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

coerce_numeric_columns <- function(data, columns) {
  for (col in intersect(columns, names(data))) {
    data[[col]] <- suppressWarnings(as.numeric(data[[col]]))
  }
  data
}

coerce_logical_column <- function(x) {
  if (is.logical(x)) {
    return(x)
  }
  if (is.numeric(x)) {
    return(x != 0)
  }
  tolower(as.character(x)) %in% c("true", "t", "1", "yes", "y")
}

prepare_long_metric_frame <- function(data,
                                      required,
                                      value_columns = NULL,
                                      chart_type = "chart",
                                      config = NULL) {
  ensure_columns(data, required, chart_type = chart_type)
  out <- data
  if (!is.null(value_columns)) {
    out <- coerce_numeric_columns(out, value_columns)
  }
  attr(out, "chart_config") <- resolve_chart_config(chart_type = chart_type, config = config)
  out
}

compute_percentile <- function(x, higher_is_better = TRUE) {
  values <- suppressWarnings(as.numeric(x))
  ranks <- rank(values, na.last = "keep", ties.method = "average")
  n <- sum(is.finite(values))
  if (n <= 1) {
    pct <- rep(50, length(values))
    pct[!is.finite(values)] <- NA_real_
  } else {
    pct <- ((ranks - 1) / (n - 1)) * 100
  }
  if (!isTRUE(higher_is_better)) {
    pct <- 100 - pct
  }
  pct
}

default_chart_title <- function(chart_type, metric_label = NULL, geo_name = NULL) {
  parts <- c(metric_label, geo_name)
  parts <- parts[!is.na(parts) & nzchar(parts)]
  if (length(parts) == 0) {
    return(tools::toTitleCase(gsub("_", " ", chart_type)))
  }
  paste(parts, collapse = ": ")
}

resolve_output_mode <- function(config = NULL, default = "notebook") {
  visual_output_mode((config %||% list())$output_mode %||% default)
}

resolve_label_box <- function(config = NULL, default = NULL) {
  mode <- resolve_output_mode(config)
  if (!is.null((config %||% list())$label_box)) {
    return(isTRUE(config$label_box))
  }
  if (!is.null(default)) {
    return(isTRUE(default))
  }
  identical(mode, "presentation")
}

value_label_formatter <- function(style = c("number", "percent", "dollar", "integer", "rank"),
                                  accuracy = NULL,
                                  compact = TRUE) {
  style <- match.arg(style)

  if (identical(style, "percent")) {
    return(format_percent(accuracy = accuracy %||% 0.1))
  }
  if (identical(style, "dollar")) {
    return(format_dollar(
      accuracy = accuracy %||% 1,
      scale_cut = if (isTRUE(compact)) scales::cut_short_scale() else NULL
    ))
  }
  if (identical(style, "integer")) {
    return(format_integer())
  }
  if (identical(style, "rank")) {
    return(format_rank())
  }

  format_number(
    accuracy = accuracy %||% if (isTRUE(compact)) 0.1 else 1,
    scale_cut = if (isTRUE(compact)) scales::cut_short_scale() else NULL
  )
}

format_value_vector <- function(values,
                                style = "number",
                                accuracy = NULL,
                                compact = TRUE) {
  value_label_formatter(
    style = style,
    accuracy = accuracy,
    compact = compact
  )(values)
}

derive_reference_value <- function(data,
                                   value_col,
                                   method = c("median", "mean", "zero", "value"),
                                   value = NULL,
                                   subset = NULL) {
  method <- match.arg(method)
  values <- data[[value_col]]
  if (!is.null(subset)) {
    values <- values[subset]
  }
  values <- suppressWarnings(as.numeric(values))

  if (identical(method, "zero")) {
    return(0)
  }
  if (identical(method, "value")) {
    return(as.numeric(value))
  }
  if (identical(method, "mean")) {
    return(mean(values, na.rm = TRUE))
  }

  stats::median(values, na.rm = TRUE)
}

benchmark_label_text <- function(label = NULL,
                                 value = NULL,
                                 value_style = "number",
                                 accuracy = NULL,
                                 prefix = NULL) {
  pieces <- compact_chr(c(label, prefix))
  if (!is.null(value) && is.finite(value)) {
    formatted <- format_value_vector(
      value,
      style = value_style,
      accuracy = accuracy
    )
    if (length(pieces) == 0) {
      return(formatted)
    }
    return(paste0(paste(pieces, collapse = " "), ": ", formatted))
  }
  paste(pieces, collapse = " ")
}

benchmark_layer <- function(data,
                            orientation = c("horizontal", "vertical"),
                            intercept,
                            label = NULL,
                            value = NULL,
                            value_style = "number",
                            accuracy = NULL,
                            config = list(),
                            position = NULL,
                            show_label = NULL) {
  orientation <- match.arg(orientation)
  cfg <- resolve_chart_config(config = config)
  bench <- benchmark_style_defaults(cfg$output_mode)
  show_label <- show_label %||% cfg$benchmark_label_default
  label_text <- benchmark_label_text(
    label = label,
    value = value %||% intercept,
    value_style = value_style,
    accuracy = accuracy
  )

  line <- if (identical(orientation, "horizontal")) {
    ggplot2::geom_hline(
      yintercept = intercept,
      color = cfg$benchmark_color %||% bench$color,
      linewidth = cfg$benchmark_linewidth %||% bench$linewidth,
      linetype = cfg$benchmark_linetype %||% bench$linetype,
      alpha = cfg$benchmark_alpha %||% bench$alpha
    )
  } else {
    ggplot2::geom_vline(
      xintercept = intercept,
      color = cfg$benchmark_color %||% bench$color,
      linewidth = cfg$benchmark_linewidth %||% bench$linewidth,
      linetype = cfg$benchmark_linetype %||% bench$linetype,
      alpha = cfg$benchmark_alpha %||% bench$alpha
    )
  }

  if (!isTRUE(show_label) || !is_nonempty_string(label_text)) {
    return(list(line = line, label = NULL))
  }

  pos <- position %||% if (identical(orientation, "horizontal")) {
    list(
      x = Inf,
      y = intercept,
      hjust = 1.02,
      vjust = -0.4
    )
  } else {
    list(
      x = intercept,
      y = Inf,
      hjust = -0.1,
      vjust = 1.1
    )
  }

  label_df <- data.frame(
    x = pos$x %||% Inf,
    y = pos$y %||% intercept,
    label = label_text,
    hjust = pos$hjust %||% 1.02,
    vjust = pos$vjust %||% -0.4
  )

  label_layer <- ggplot2::geom_text(
    data = label_df,
    ggplot2::aes(x = .data$x, y = .data$y, label = .data$label),
    inherit.aes = FALSE,
    color = bench$text_color,
    size = bench$text_size,
    hjust = label_df$hjust[[1]],
    vjust = label_df$vjust[[1]]
  )

  list(line = line, label = label_layer)
}

apply_benchmark_layer <- function(plot, benchmark) {
  if (is.null(benchmark)) {
    return(plot)
  }
  if (!is.null(benchmark$line)) {
    plot <- plot + benchmark$line
  }
  if (!is.null(benchmark$label)) {
    plot <- plot + benchmark$label
  }
  plot
}

pick_label_rows <- function(data,
                            flag_col = "label_flag",
                            highlight_col = "highlight_flag",
                            value_col = NULL,
                            top_n = NULL) {
  out <- data
  keep <- rep(FALSE, nrow(out))

  if (flag_col %in% names(out)) {
    keep <- keep | coerce_logical_column(out[[flag_col]])
  }
  if (highlight_col %in% names(out)) {
    keep <- keep | coerce_logical_column(out[[highlight_col]])
  }
  if (!is.null(top_n) && !is.null(value_col) && value_col %in% names(out)) {
    ord <- order(out[[value_col]], decreasing = TRUE, na.last = NA)
    keep[utils::head(ord, top_n)] <- TRUE
  }

  out[keep %in% TRUE, , drop = FALSE]
}

label_layer <- function(data,
                        mapping,
                        config = list(),
                        boxed = NULL,
                        repel = TRUE,
                        ...) {
  cfg <- resolve_chart_config(config = config)
  boxed <- boxed %||% resolve_label_box(cfg)

  if (nrow(data) == 0) {
    return(NULL)
  }

  if (isTRUE(boxed) && repel && requireNamespace("ggrepel", quietly = TRUE)) {
    return(ggrepel::geom_label_repel(
      data = data,
      mapping = mapping,
      size = cfg$label_size,
      label.size = 0.15,
      label.padding = grid::unit(0.12, "lines"),
      fill = visual_neutral_palette()$background_white,
      color = visual_neutral_palette()$text,
      box.padding = 0.25,
      min.segment.length = 0,
      seed = 123,
      ...
    ))
  }

  if (isTRUE(boxed)) {
    return(ggplot2::geom_label(
      data = data,
      mapping = mapping,
      size = cfg$label_size,
      label.size = 0.15,
      fill = visual_neutral_palette()$background_white,
      color = visual_neutral_palette()$text,
      ...
    ))
  }

  if (repel && requireNamespace("ggrepel", quietly = TRUE)) {
    return(ggrepel::geom_text_repel(
      data = data,
      mapping = mapping,
      size = cfg$label_size,
      color = visual_neutral_palette()$text,
      box.padding = 0.25,
      min.segment.length = 0,
      seed = 123,
      ...
    ))
  }

  ggplot2::geom_text(
    data = data,
    mapping = mapping,
    size = cfg$label_size,
    color = visual_neutral_palette()$text,
    ...
  )
}

annotation_note_label <- function(text,
                                  x,
                                  y,
                                  boxed = TRUE,
                                  config = list(),
                                  hjust = 0,
                                  vjust = 1) {
  if (!is_nonempty_string(text)) {
    return(NULL)
  }

  cfg <- resolve_chart_config(config = config)
  note_df <- data.frame(x = x, y = y, label = text)

  if (isTRUE(boxed)) {
    return(ggplot2::geom_label(
      data = note_df,
      ggplot2::aes(x = .data$x, y = .data$y, label = .data$label),
      inherit.aes = FALSE,
      hjust = hjust,
      vjust = vjust,
      size = cfg$label_size,
      label.size = 0.15,
      fill = visual_neutral_palette()$background_white,
      color = visual_neutral_palette()$text
    ))
  }

  ggplot2::geom_text(
    data = note_df,
    ggplot2::aes(x = .data$x, y = .data$y, label = .data$label),
    inherit.aes = FALSE,
    hjust = hjust,
    vjust = vjust,
    size = cfg$label_size,
    color = visual_neutral_palette()$text
  )
}

chart_caption_from_config <- function(data = NULL, config = list(), caption = NULL) {
  if (!is.null(caption)) {
    return(caption)
  }

  cfg <- resolve_chart_config(config = config)
  build_chart_notes(
    source = extract_chart_metadata(data, "source"),
    vintage = extract_chart_metadata(data, "vintage"),
    side_note = cfg$caption_side_note,
    footer_note = cfg$caption_footer_note,
    methodology_note = cfg$caption_methodology_note
  )
}
