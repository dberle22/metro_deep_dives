# Prepare proportional symbol map data.

source("R/visual/chart_utils.R")
source("R/visual/data_contracts.R")

prep_proportional_symbol_map <- function(data, config = list()) {
  validate_proportional_symbol_map_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$proportional_symbol_map$required_fields,
    value_columns = c("size_value", "lon", "lat"),
    chart_type = "proportional_symbol_map",
    config = config
  )
  out
}
