# Prepare age pyramid data.

source("visual_library/shared/chart_utils.R")
source("visual_library/shared/data_contracts.R")

prep_age_pyramid <- function(data, config = list()) {
  validate_age_pyramid_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$age_pyramid$required_fields,
    value_columns = c("pop_value", "pop_share"),
    chart_type = "age_pyramid",
    config = config
  )
  if (!"pop_share" %in% names(out) || all(is.na(out$pop_share))) {
    out$pop_share <- ave(out$pop_value, out$geo_id, FUN = function(x) x / sum(x, na.rm = TRUE))
  }
  out$plot_value <- ifelse(tolower(out$sex) %in% c("male", "m"), -out$pop_share, out$pop_share)
  out
}
