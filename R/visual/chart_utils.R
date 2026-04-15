# Shared helpers used across visual library prep/render functions.

source("R/visual/standards.R")

ensure_columns <- function(data, required, chart_type = "chart") {
  stopifnot(is.data.frame(data))
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(
      sprintf(
        "%s is missing required columns: %s",
        chart_type,
        paste(missing, collapse = ", ")
      )
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
  attr(out, "chart_config") <- config %||% list()
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
