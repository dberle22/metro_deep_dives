source("notebooks/retail_opportunity_finder/data_platform/layers/02_tract_scoring/tract_scoring_workflow.R")

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

ensure_rof_duckdb_schemas(con)
products <- build_tract_scoring_products(con)
publish_counts <- publish_tract_scoring_products(con, products)

message(
  "Tract scoring layer complete for ",
  products$profile$market_key,
  ": ",
  publish_counts$tract_scores,
  " tract score rows and ",
  publish_counts$cluster_seed_tracts,
  " cluster seed rows published."
)
