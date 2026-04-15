# Prepare bump chart data.

source("R/visual/chart_utils.R")
source("R/visual/data_contracts.R")

prep_bump_chart <- function(data, config = list()) {
  validate_bump_chart_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$bump_chart$required_fields,
    value_columns = c("metric_value", "rank"),
    chart_type = "bump_chart",
    config = config
  )
  if (!"rank" %in% names(out) || all(is.na(out$rank))) {
    out$rank <- ave(out$metric_value, out$period, FUN = function(x) rank(-x, ties.method = "first"))
  }
  out
}
