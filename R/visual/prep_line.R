# Prepare line chart data for rendering.

source("R/visual/chart_utils.R")
source("R/visual/data_contracts.R")

prep_line <- function(data, config = list()) {
  cfg <- merge_chart_config(
    list(
      metric_id = NULL,
      variant = "single",
      geo_ids = NULL,
      period_min = NULL,
      period_max = NULL,
      base_period = NULL,
      rolling_k = 3
    ),
    config
  )

  validate_line_contract(data)
  out <- prepare_long_metric_frame(
    data = data,
    required = visual_contracts$line$required_fields,
    value_columns = "metric_value",
    chart_type = "line",
    config = cfg
  )

  if (!is.null(cfg$metric_id)) {
    out <- out[out$metric_id == cfg$metric_id, , drop = FALSE]
  }
  if (!is.null(cfg$geo_ids)) {
    out <- out[out$geo_id %in% cfg$geo_ids, , drop = FALSE]
  }
  if (!is.null(cfg$period_min)) {
    out <- out[out$period >= cfg$period_min, , drop = FALSE]
  }
  if (!is.null(cfg$period_max)) {
    out <- out[out$period <= cfg$period_max, , drop = FALSE]
  }
  if (nrow(out) == 0) {
    stop("No rows left after line prep filtering; adjust config.")
  }

  out <- out[order(out$geo_id, out$period), , drop = FALSE]
  out$plot_value <- out$metric_value
  out$variant <- cfg$variant

  if (identical(cfg$variant, "indexed")) {
    base_period <- cfg$base_period %||% min(out$period, na.rm = TRUE)
    parts <- split(out, out$geo_id)
    parts <- lapply(parts, function(df) {
      base_row <- df[df$period == base_period, , drop = FALSE]
      if (nrow(base_row) == 0 || !is.finite(base_row$metric_value[1]) || base_row$metric_value[1] == 0) {
        df$plot_value <- NA_real_
      } else {
        df$plot_value <- (df$metric_value / base_row$metric_value[1]) * 100
      }
      df$time_window <- "indexed"
      df$index_base_period <- base_period
      df
    })
    out <- do.call(rbind, parts)
  }

  if (identical(cfg$variant, "rolling")) {
    if (cfg$rolling_k < 2) {
      stop("rolling_k must be >= 2.")
    }
    parts <- split(out, out$geo_id)
    parts <- lapply(parts, function(df) {
      df$plot_value <- as.numeric(stats::filter(df$metric_value, rep(1 / cfg$rolling_k, cfg$rolling_k), sides = 1))
      df$time_window <- paste0("rolling_", cfg$rolling_k, "yr")
      df
    })
    out <- do.call(rbind, parts)
  }

  out
}
