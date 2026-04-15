# Prepare correlation heatmap data.

source("R/visual/chart_utils.R")
source("R/visual/data_contracts.R")

prep_correlation_heatmap <- function(data, config = list()) {
  cfg <- merge_chart_config(list(method = "spearman"), config)
  validate_correlation_heatmap_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$correlation_heatmap$required_fields,
    value_columns = "metric_value",
    chart_type = "correlation_heatmap",
    config = cfg
  )

  wide <- stats::reshape(
    out[, c("geo_id", "metric_label", "metric_value")],
    idvar = "geo_id",
    timevar = "metric_label",
    direction = "wide"
  )
  rownames(wide) <- wide$geo_id
  wide$geo_id <- NULL
  corr <- stats::cor(wide, use = "pairwise.complete.obs", method = cfg$method)

  expand.grid(metric_x = colnames(corr), metric_y = rownames(corr), stringsAsFactors = FALSE) |>
    transform(correlation = as.vector(corr))
}
