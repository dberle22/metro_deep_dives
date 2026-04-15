# Prepare hexbin data.

source("R/visual/chart_utils.R")
source("R/visual/data_contracts.R")

prep_hexbin <- function(data, config = list()) {
  cfg <- merge_chart_config(list(time_window = NULL), config)
  validate_hexbin_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$hexbin$required_fields,
    value_columns = c("x_value", "y_value", "weight_value"),
    chart_type = "hexbin",
    config = cfg
  )
  if (!is.null(cfg$time_window)) {
    out <- out[out$time_window == cfg$time_window, , drop = FALSE]
  }
  out <- out[is.finite(out$x_value) & is.finite(out$y_value), , drop = FALSE]
  out
}
