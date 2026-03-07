# Prepare scatter chart data for rendering.

prep_scatter <- function(data,
                         time_window = NULL,
                         require_single_geo_level = TRUE,
                         drop_missing_xy = TRUE) {
  stopifnot(is.data.frame(data))

  if (!exists("scatter_contract_standard", mode = "list")) {
    source("R/visual/data_contracts.R")
  }

  required <- scatter_contract_standard$required_fields
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(paste("Missing required columns:", paste(missing, collapse = ", ")))
  }

  out <- data

  if (!is.null(time_window)) {
    out <- out[out$time_window == time_window, , drop = FALSE]
  }

  if (isTRUE(require_single_geo_level)) {
    gl_n <- length(unique(out$geo_level))
    if (gl_n > 1) {
      stop("Scatter input contains multiple geo_levels; filter to one level per chart.")
    }
  }

  out$x_value <- as.numeric(out$x_value)
  out$y_value <- as.numeric(out$y_value)

  if (isTRUE(drop_missing_xy)) {
    out <- out[is.finite(out$x_value) & is.finite(out$y_value), , drop = FALSE]
  }

  if (nrow(out) == 0) {
    stop("No rows left after scatter prep filtering.")
  }

  out
}
