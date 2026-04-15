# Prepare heatmap table data.

source("visual_library/shared/chart_utils.R")
source("visual_library/shared/data_contracts.R")

prep_heatmap_table <- function(data, config = list()) {
  cfg <- merge_chart_config(list(value_field = "metric_value"), config)
  validate_heatmap_table_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$heatmap_table$required_fields,
    value_columns = c("metric_value", "normalized_value"),
    chart_type = "heatmap_table",
    config = cfg
  )
  if (!"normalized_value" %in% names(out) || all(is.na(out$normalized_value))) {
    out$normalized_value <- ave(out$metric_value, out$metric_id, FUN = compute_percentile)
  }
  out$column_label <- out$metric_label
  if ("period" %in% names(out) && !all(is.na(out$period))) {
    out$column_label <- as.character(out$period)
  }
  out
}
