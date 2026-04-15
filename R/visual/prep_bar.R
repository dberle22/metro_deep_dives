# Prepare ranked bar chart datasets for rendering.

source("R/visual/chart_utils.R")
source("R/visual/data_contracts.R")

prep_bar <- function(data, config = list()) {
  cfg <- merge_chart_config(
    list(
      question_id = NULL,
      time_window = NULL,
      metric_id = NULL,
      top_n = NULL,
      sort_desc = TRUE,
      include_geo_ids = NULL,
      drop_na_metric = TRUE,
      variant = "ranked_horizontal"
    ),
    config
  )

  validate_bar_contract(data)
  out <- prepare_long_metric_frame(
    data = data,
    required = visual_contracts$bar$required_fields,
    value_columns = c("metric_value", "benchmark_value", "share_value", "rank"),
    chart_type = "bar",
    config = cfg
  )

  if (!is.null(cfg$question_id) && "question_id" %in% names(out)) {
    out <- out[out$question_id == cfg$question_id, , drop = FALSE]
  }
  if (!is.null(cfg$time_window) && "time_window" %in% names(out)) {
    out <- out[out$time_window == cfg$time_window, , drop = FALSE]
  }
  if (!is.null(cfg$metric_id)) {
    out <- out[out$metric_id == cfg$metric_id, , drop = FALSE]
  }
  if (isTRUE(cfg$drop_na_metric)) {
    out <- out[is.finite(out$metric_value), , drop = FALSE]
  }
  if (nrow(out) == 0) {
    stop("No rows left after bar prep filtering; adjust config.")
  }

  if ("highlight_flag" %in% names(out)) {
    out$highlight_flag <- coerce_logical_column(out$highlight_flag)
  }

  out <- out[order(out$metric_value, decreasing = isTRUE(cfg$sort_desc)), , drop = FALSE]

  if (!is.null(cfg$top_n)) {
    trimmed <- utils::head(out, cfg$top_n)

    if (!is.null(cfg$include_geo_ids)) {
      keep_extra <- out$geo_id %in% cfg$include_geo_ids
      extras <- out[keep_extra & !(out$geo_id %in% trimmed$geo_id), , drop = FALSE]
      if (nrow(extras) > 0) {
        trimmed <- rbind(trimmed, extras)
        trimmed <- trimmed[order(trimmed$metric_value, decreasing = isTRUE(cfg$sort_desc)), , drop = FALSE]
      }
    }

    out <- trimmed
  }

  out$display_order <- seq_len(nrow(out))
  out$rank <- rank(-out$metric_value, ties.method = "first")
  if (!isTRUE(cfg$sort_desc)) {
    out$rank <- rank(out$metric_value, ties.method = "first")
  }

  out
}
