# Prepare highlight-context map data.

source("R/visual/chart_utils.R")
source("R/visual/data_contracts.R")

prep_highlight_context_map <- function(data, config = list()) {
  validate_highlight_context_map_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$highlight_context_map$required_fields,
    value_columns = c("metric_value"),
    chart_type = "highlight_context_map",
    config = config
  )
  out$highlight_flag <- coerce_logical_column(out$highlight_flag)
  out
}
