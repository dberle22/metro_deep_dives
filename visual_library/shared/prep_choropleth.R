# Prepare choropleth data.

source("visual_library/shared/chart_utils.R")
source("visual_library/shared/data_contracts.R")

prep_choropleth <- function(data, config = list()) {
  cfg <- merge_chart_config(
    list(time_window = NULL, bins = NULL, metric_id = NULL),
    config
  )
  validate_choropleth_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$choropleth$required_fields,
    value_columns = c("metric_value", "benchmark_value"),
    chart_type = "choropleth",
    config = cfg
  )

  if (!is.null(cfg$time_window) && "time_window" %in% names(out)) {
    out <- out[out$time_window == cfg$time_window, , drop = FALSE]
  }

  if (is.null(out$bin) && !is.null(cfg$bins) && length(unique(stats::na.omit(out$metric_value))) > 1) {
    out$bin <- cut(out$metric_value, breaks = cfg$bins, include.lowest = TRUE)
  }

  out
}
