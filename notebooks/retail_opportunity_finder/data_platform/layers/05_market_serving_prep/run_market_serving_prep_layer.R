source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/market_serving_prep_workflow.R")

message("Running Layer 05 market serving prep for all markets")

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
previous_s2_option <- sf::sf_use_s2(FALSE)
on.exit(sf::sf_use_s2(previous_s2_option), add = TRUE)

# Get all markets that have retail parcels
market_profiles <- DBI::dbGetQuery(con, "
  SELECT DISTINCT
    mcm.market_key,
    mcm.cbsa_code,
    mcm.cbsa_name
  FROM ref.market_county_membership mcm
  INNER JOIN parcel.parcels_canonical pc
  ON mcm.market_key = pc.market_key
  ORDER BY mcm.market_key
") %>%
  as_tibble()

if (nrow(market_profiles) == 0) {
  stop("No markets found with retail parcels.", call. = FALSE)
}

message(glue::glue("Found {nrow(market_profiles)} markets with parcels"))

products <- build_market_serving_layer_publications(con, market_profiles)
publish_counts <- publish_market_serving_products(con, products)

message(glue::glue(
  "Layer 05 publish complete for {nrow(market_profiles)} markets: ",
  publish_counts$retail_parcel_tract_assignment, " retail parcel tract assignments, ",
  publish_counts$retail_intensity_by_tract, " tract intensity rows, ",
  publish_counts$parcel_zone_overlay, " zone overlay rows, ",
  publish_counts$parcel_shortlist, " shortlist rows, ",
  publish_counts$parcel_shortlist_summary, " shortlist summary rows, ",
  publish_counts$qa_validation_results, " serving QA rows."
))
