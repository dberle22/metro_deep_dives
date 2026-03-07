# Prepare line chart data for rendering.
prep_line <- function(data,
                      metric_id,
                      variant = c("single", "multi", "indexed", "rolling"),
                      geo_ids = NULL,
                      period_min = NULL,
                      period_max = NULL,
                      base_period = NULL,
                      rolling_k = 3) {
  variant <- match.arg(variant)
  stopifnot(is.data.frame(data))

  required <- c("geo_level", "geo_id", "geo_name", "period", "metric_id", "metric_label", "metric_value", "source", "vintage")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(paste("Missing required columns:", paste(missing, collapse = ", ")))
  }

  out <- data[data$metric_id == metric_id, , drop = FALSE]

  if (!is.null(geo_ids)) {
    out <- out[out$geo_id %in% geo_ids, , drop = FALSE]
  }
  if (!is.null(period_min)) {
    out <- out[out$period >= period_min, , drop = FALSE]
  }
  if (!is.null(period_max)) {
    out <- out[out$period <= period_max, , drop = FALSE]
  }
  if (nrow(out) == 0) {
    stop("No rows left after filtering; adjust metric/geography/period filters.")
  }

  out$metric_value <- as.numeric(out$metric_value)
  out <- out[order(out$geo_id, out$period), , drop = FALSE]
  out$plot_value <- out$metric_value

  if (variant == "indexed") {
    if (is.null(base_period)) {
      base_period <- min(out$period, na.rm = TRUE)
    }

    idx <- split(out, out$geo_id)
    idx <- lapply(idx, function(df) {
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
    out <- do.call(rbind, idx)
    out <- out[order(out$geo_id, out$period), , drop = FALSE]
  }

  if (variant == "rolling") {
    if (rolling_k < 2) stop("rolling_k must be >= 2 for rolling variant.")
    idx <- split(out, out$geo_id)
    idx <- lapply(idx, function(df) {
      df$plot_value <- as.numeric(stats::filter(df$metric_value, rep(1 / rolling_k, rolling_k), sides = 1))
      df$time_window <- paste0("rolling_", rolling_k, "yr")
      df
    })
    out <- do.call(rbind, idx)
    out <- out[order(out$geo_id, out$period), , drop = FALSE]
  }

  out$variant <- variant
  out
}
