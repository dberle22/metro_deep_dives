# Prepare waterfall data.

source("R/visual/chart_utils.R")
source("R/visual/data_contracts.R")

prep_waterfall <- function(data, config = list()) {
  validate_waterfall_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$waterfall$required_fields,
    value_columns = c("component_value", "component_delta"),
    chart_type = "waterfall",
    config = config
  )
  value_col <- if ("component_delta" %in% names(out) && any(!is.na(out$component_delta))) "component_delta" else "component_value"
  out$plot_value <- out[[value_col]]
  out$sort_order <- out$sort_order %||% seq_len(nrow(out))
  out <- out[order(out$sort_order, out$component_label), , drop = FALSE]
  out$cumulative_end <- cumsum(out$plot_value)
  out$cumulative_start <- c(0, utils::head(out$cumulative_end, -1))
  out
}
