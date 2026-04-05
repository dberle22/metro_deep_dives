source("notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features/foundation_feature_workflow.R")

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

products <- build_foundation_products(con)
qa_outputs <- build_foundation_qa(products)
publish_counts <- publish_foundation_products(con, products, qa_outputs)

message(
  "Foundation layer complete for ",
  products$profile$market_key,
  ": ",
  publish_counts$cbsa_features, " cbsa rows, ",
  publish_counts$tract_features, " tract rows, ",
  publish_counts$market_tract_geometry, " market tract geometry rows, ",
  publish_counts$market_county_geometry, " market county geometry rows, ",
  publish_counts$validation_results, " QA validation rows."
)
