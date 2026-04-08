source("notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features/foundation_feature_workflow.R")

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

products <- build_foundation_products(con)
qa_outputs <- build_foundation_qa(con, products)
publish_counts <- publish_foundation_products(con, products, qa_outputs)

message(
  "Foundation layer complete. Active market context: ",
  products$profile$market_key,
  ". Published national managed outputs: ",
  publish_counts$cbsa_features, " cbsa rows, ",
  publish_counts$tract_features, " tract rows, ",
  publish_counts$market_tract_geometry, " tract geometry rows, ",
  publish_counts$market_county_geometry, " county geometry rows, ",
  publish_counts$market_cbsa_geometry, " cbsa geometry rows. ",
  "QA rows: ", publish_counts$validation_results, " validation, ",
  publish_counts$geography_coverage, " geography coverage, ",
  publish_counts$null_rates, " null-rate. ",
  "Key QA signals: ",
  sum(is.na(products$tract_features$cbsa_code) | products$tract_features$cbsa_code == ""), " tract rows with null/blank cbsa_code; ",
  dplyr::n_distinct(products$tract_features$cbsa_code, na.rm = TRUE), " non-null tract CBSAs; ",
  dplyr::n_distinct(products$market_cbsa_geometry$cbsa_code, na.rm = TRUE), " CBSA geometry rows."
)
