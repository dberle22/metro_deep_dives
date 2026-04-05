source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

source("notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/parcel_standardization_workflow.R")

message(glue::glue("Running Layer 04 parcel standardization for market {ACTIVE_MARKET_KEY}"))

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

products <- build_parcel_standardization_products(con, profile = get_market_profile())
publish_counts <- publish_parcel_standardization_products(con, products)

message(glue::glue(
  "Layer 04 publish complete: ",
  publish_counts$parcels_canonical, " canonical parcels, ",
  publish_counts$parcel_join_qa, " parcel QA rows, ",
  publish_counts$parcel_lineage, " parcel lineage rows, ",
  publish_counts$retail_parcels, " retail parcel rows, ",
  publish_counts$qa_validation_results, " parcel validation rows."
))
