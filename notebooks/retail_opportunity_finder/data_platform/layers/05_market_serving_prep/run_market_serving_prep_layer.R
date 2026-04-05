source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/market_serving_prep_workflow.R")

message(glue::glue("Running Layer 05 market serving prep for market {ACTIVE_MARKET_KEY}"))

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
previous_s2_option <- sf::sf_use_s2(FALSE)
on.exit(sf::sf_use_s2(previous_s2_option), add = TRUE)

products <- build_market_serving_products(con, profile = get_market_profile())
publish_counts <- publish_market_serving_products(con, products)

message(glue::glue(
  "Layer 05 publish complete: ",
  publish_counts$retail_parcel_tract_assignment, " retail parcel tract assignments, ",
  publish_counts$retail_intensity_by_tract, " tract intensity rows, ",
  publish_counts$parcel_zone_overlay, " zone overlay rows, ",
  publish_counts$parcel_shortlist, " shortlist rows, ",
  publish_counts$parcel_shortlist_summary, " shortlist summary rows, ",
  publish_counts$qa_validation_results, " serving QA rows."
))
