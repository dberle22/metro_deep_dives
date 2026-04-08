#!/usr/bin/env Rscript
# Test Layer 05 tables individually to isolate issues

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

library(DBI)
library(duckdb)
library(dplyr)
library(glue)

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

# Load Layer 05 helpers
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/market_serving_prep_workflow.R")

message("=== Testing Layer 05 individual components ===\n")

# Get a single market to test with
test_market <- DBI::dbGetQuery(con, "
  SELECT DISTINCT
    mcm.market_key,
    mcm.cbsa_code,
    mcm.cbsa_name
  FROM ref.market_county_membership mcm
  INNER JOIN parcel.parcels_canonical pc
  ON mcm.market_key = pc.market_key
  ORDER BY mcm.market_key
  LIMIT 1
") %>%
  as_tibble()

if (nrow(test_market) == 0) {
  stop("No markets found with parcels", call. = FALSE)
}

profile <- test_market[1, ]
message(glue("Testing with market: {profile$market_key} ({profile$cbsa_code})\n"))

# Test 1: Check parcel.parcel_join_qa table
message("=== Test 1: Reading parcel_join_qa ===")
tryCatch({
  parcel_join_qa <- read_market_parcel_join_qa(con, profile)
  message(glue("✓ parcel_join_qa: {nrow(parcel_join_qa)} rows"))
  print(head(parcel_join_qa, 3))
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
})

# Test 2: Check parcel.parcels_canonical
message("=== Test 2: Reading retail parcels ===")
tryCatch({
  retail_parcels <- read_market_retail_parcels(con, profile)
  message(glue("✓ retail_parcels: {nrow(retail_parcels)} rows"))
  print(head(retail_parcels, 3))
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
})

# Test 3: Check foundation.market_tract_geometry
message("=== Test 3: Reading tract geometry ===")
tryCatch({
  tract_sf <- read_market_tract_geometry(con, profile)
  message(glue("✓ tract_sf: {nrow(tract_sf)} rows"))
  message(glue("  CRS: {sf::st_crs(tract_sf)$epsg}"))
  print(head(tract_sf, 3))
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
})

# Test 4: Check zone assignments
message("=== Test 4: Reading zone assignments ===")
tryCatch({
  zone_assignments <- read_market_zone_assignments(con, profile)
  message(glue("✓ zone_assignments: {nrow(zone_assignments)} rows"))
  print(head(zone_assignments, 3))
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
})

# Test 5: Check zone summaries
message("=== Test 5: Reading zone summaries ===")
tryCatch({
  zone_summaries <- read_market_zone_summaries(con, profile)
  message(glue("✓ zone_summaries: {nrow(zone_summaries)} rows"))
  print(head(zone_summaries, 3))
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
})

# Test 6: Try to read parcel geometry lookup
message("=== Test 6: Reading parcel geometry lookup ===")
tryCatch({
  if (nrow(parcel_join_qa) == 0) {
    message("⚠ Skipping: no parcel_join_qa data")
  } else {
    geometry_lookup <- read_market_parcel_geometry_lookup(parcel_join_qa)
    message(glue("✓ geometry_lookup: {nrow(geometry_lookup)} rows"))
    print(head(geometry_lookup, 3))
  }
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
  message("Note: This is expected if parcel geometry files don't exist yet.\n")
})

message("=== Test Summary ===")
message("If geometry lookup failed, we need to either:")
message("  1. Generate parcel geometry files from Layer 04, or")
message("  2. Read parcel geometries directly from database")
