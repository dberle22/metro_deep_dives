# Data contract standards and validators for visual artifacts.

scatter_contract_standard <- list(
  required_fields = c(
    "geo_level", "geo_id", "geo_name", "time_window",
    "x_value", "y_value", "x_label", "y_label"
  ),
  optional_fields = c(
    "source", "vintage", "group", "size_value",
    "label_flag", "note", "x_metric_id", "y_metric_id"
  )
)

validate_scatter_contract <- function(data,
                                      require_single_geo_level = TRUE,
                                      require_single_time_window = TRUE,
                                      require_complete_xy = TRUE) {
  stopifnot(is.data.frame(data))

  required <- scatter_contract_standard$required_fields
  optional <- scatter_contract_standard$optional_fields
  missing_required <- setdiff(required, names(data))

  result <- list(
    pass = TRUE,
    rows = nrow(data),
    missing_required = missing_required,
    present_optional = intersect(optional, names(data)),
    checks = list()
  )

  if (length(missing_required) > 0) {
    result$pass <- FALSE
  }

  if (nrow(data) == 0) {
    result$pass <- FALSE
    result$checks$non_empty <- FALSE
  } else {
    result$checks$non_empty <- TRUE
  }

  if (all(c("geo_level") %in% names(data))) {
    geo_levels <- unique(data$geo_level)
    result$checks$geo_level_count <- length(geo_levels)
    if (isTRUE(require_single_geo_level) && length(geo_levels) != 1) {
      result$pass <- FALSE
    }
  }

  if (all(c("time_window") %in% names(data))) {
    windows <- unique(data$time_window)
    result$checks$time_window_count <- length(windows)
    if (isTRUE(require_single_time_window) && length(windows) != 1) {
      result$pass <- FALSE
    }
  }

  if (all(c("x_value", "y_value") %in% names(data))) {
    missing_x <- sum(!is.finite(as.numeric(data$x_value)))
    missing_y <- sum(!is.finite(as.numeric(data$y_value)))
    result$checks$missing_x <- missing_x
    result$checks$missing_y <- missing_y
    if (isTRUE(require_complete_xy) && (missing_x > 0 || missing_y > 0)) {
      result$pass <- FALSE
    }
  }

  class(result) <- c("scatter_contract_validation", class(result))
  result
}
