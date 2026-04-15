# Prepare slopegraph data.

source("visual_library/shared/chart_utils.R")
source("visual_library/shared/data_contracts.R")

prep_slopegraph <- function(data, config = list()) {
  cfg <- merge_chart_config(list(periods = NULL, order_by = "end_value"), config)
  validate_slopegraph_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$slopegraph$required_fields,
    value_columns = "metric_value",
    chart_type = "slopegraph",
    config = cfg
  )

  periods <- cfg$periods %||% sort(unique(out$period))
  if (length(periods) != 2) {
    stop("Slopegraph requires exactly two periods.")
  }
  out <- out[out$period %in% periods, , drop = FALSE]
  out
}
