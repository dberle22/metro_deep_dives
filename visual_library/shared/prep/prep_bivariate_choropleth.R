# Prepare bivariate choropleth data.

source("visual_library/shared/chart_utils.R")
source("visual_library/shared/data_contracts.R")

prep_bivariate_choropleth <- function(data, config = list()) {
  validate_bivariate_choropleth_contract(data)
  out <- prepare_long_metric_frame(
    data,
    required = visual_contracts$bivariate_choropleth$required_fields,
    value_columns = c("x_value", "y_value"),
    chart_type = "bivariate_choropleth",
    config = config
  )
  if (!"x_bin" %in% names(out) || !("y_bin" %in% names(out))) {
    out$x_bin <- cut(out$x_value, breaks = stats::quantile(out$x_value, probs = seq(0, 1, length.out = 4), na.rm = TRUE), include.lowest = TRUE, labels = FALSE)
    out$y_bin <- cut(out$y_value, breaks = stats::quantile(out$y_value, probs = seq(0, 1, length.out = 4), na.rm = TRUE), include.lowest = TRUE, labels = FALSE)
  }
  out$bivar_class <- paste(out$x_bin, out$y_bin, sep = "-")
  out
}
