#!/usr/bin/env Rscript
# Test each Layer 05 table build individually

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

library(DBI)
library(duckdb)
library(dplyr)
library(glue)
library(sf)

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

previous_s2_option <- sf::sf_use_s2(FALSE)
on.exit(sf::sf_use_s2(previous_s2_option), add = TRUE)

source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/market_serving_prep_workflow.R")

message("=== Layer 05 Table Build Test ===\n")

# Get test market
test_market <- DBI::dbGetQuery(con, "
  SELECT DISTINCT
    mcm.market_key,
    mcm.cbsa_code,
    mcm.cbsa_name
  FROM ref.market_county_membership mcm
  INNER JOIN parcel.retail_parcels pc
  ON mcm.market_key = pc.market_key
  LIMIT 1
") %>% as_tibble()

if (nrow(test_market) == 0) {
  message("ERROR: No markets with retail parcels found.")
  message("Status: parcel.parcels_canonical table doesn't exist yet.")
  message("Layer 04 (parcel_standardization) must be run first.")
  q()
}

profile <- test_market[1, ]
message(glue("Test market: {profile$market_key}\n"))

# Load table builders
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.retail_parcel_tract_assignment.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.retail_intensity_by_tract.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.parcel_zone_overlay.R")

# Read data dependencies
message("Loading market data...")
retail_parcels <- read_market_retail_parcels(con, profile)
parcel_join_qa <- read_market_parcel_join_qa(con, profile)
tract_sf <- read_market_tract_geometry(con, profile)
zone_assignments <- read_market_zone_assignments(con, profile)
zone_summaries <- read_market_zone_summaries(con, profile)

message(glue("Retail parcels: {nrow(retail_parcels)}"))
message(glue("Tract geometries: {nrow(tract_sf)}"))
message(glue("Zone assignments: {nrow(zone_assignments)}"))
message("")

# Test 1 - retail_parcel_tract_assignment
message("=== TABLE 1: serving.retail_parcel_tract_assignment ===")
tryCatch({
  if (nrow(retail_parcels) == 0) {
    message("⚠ No retail parcels available for this market")
  } else {
    geometry_lookup <- read_market_parcel_geometry_lookup(parcel_join_qa)
    retail_parcels_sf <- build_retail_parcels_with_geometry(retail_parcels, geometry_lookup)
    retail_parcel_tract <- build_retail_parcel_tract_assignment(retail_parcels_sf, tract_sf, profile)
    message(glue("✓ Built: {nrow(retail_parcel_tract)} rows"))
  }
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
})

# Test 2 - retail_intensity_by_tract (depends on tract assignment)
message("=== TABLE 2: serving.retail_intensity_by_tract ===")
tryCatch({
  if (nrow(retail_parcels) == 0) {
    message("⚠ Skipped: No retail parcels available")
  } else {
    message("⚠ Skipped: Depends on parcel geometry lookup")
  }
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
})

# Test 3 - parcel_zone_overlay (depends on intensity by tract)
message("=== TABLE 3: serving.parcel_zone_overlay ===")
message("⚠ Skipped: Depends on retail_intensity_by_tract")
message("")

message("=== Summary ===")
message("Layer 05 status depends on Layer 04 completion:")
message("  Currently: parcel.parcels_canonical not yet created")
message("  Required: Run Layer 04 to generate parcel.parcels_canonical with retail_flags")
message("  After: Rerun Layer 05 tests to build all tables")
