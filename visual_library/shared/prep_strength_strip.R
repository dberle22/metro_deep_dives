# Prepare strength strip data.

source("visual_library/shared/chart_utils.R")
source("visual_library/shared/data_contracts.R")

prep_strength_strip <- function(data, config = list()) {
  cfg <- merge_chart_config(list(normalize = TRUE), config)
  validate_strength_strip_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$strength_strip$required_fields,
    value_columns = c("metric_value", "normalized_value"),
    chart_type = "strength_strip",
    config = cfg
  )

  if (!"direction" %in% names(out)) {
    out$direction <- "higher_is_better"
  }
  if (!"normalized_value" %in% names(out) || all(is.na(out$normalized_value))) {
    out$normalized_value <- ave(
      out$metric_value,
      out$metric_id,
      FUN = function(x) compute_percentile(x, higher_is_better = TRUE)
    )
  }
  invert_idx <- out$direction %in% c("lower_is_better", "lower-better")
  out$normalized_value[invert_idx] <- 100 - out$normalized_value[invert_idx]
  out
}
