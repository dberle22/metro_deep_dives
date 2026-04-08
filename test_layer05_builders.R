#!/usr/bin/env Rscript
# Test individual Layer 05 table builders

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

# Load Layer 05 helpers and builders
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/market_serving_prep_workflow.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.retail_parcel_tract_assignment.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.retail_intensity_by_tract.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.parcel_zone_overlay.R")

message("=== Layer 05 Individual Table Builders ===\n")

# Get test market
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
") %>% as_tibble()

profile <- test_market[1, ]
message(glue("Testing with market: {profile$market_key}\n"))

# Read base data
message("Loading data dependencies...")
parcel_join_qa <- read_market_parcel_join_qa(con, profile)
retail_parcels <- read_market_retail_parcels(con, profile)
tract_sf <- read_market_tract_geometry(con, profile)
zone_assignments <- read_market_zone_assignments(con, profile)
zone_summaries <- read_market_zone_summaries(con, profile)

message(glue("  parcel_join_qa: {nrow(parcel_join_qa)} rows"))
message(glue("  retail_parcels: {nrow(retail_parcels)} rows"))
message(glue("  tract_sf: {nrow(tract_sf)} rows\n"))

# Try building tables that don't depend on parcel geometry
message("=== Table 1: retail_parcel_tract_assignment ===")
tryCatch({
  if (nrow(retail_parcels) == 0) {
    message("⚠ Skipped: No retail parcels found (retail_flag=FALSE for all parcels)")
  } else {
    # Would normally build from geometry, but we don't have it
    message("Would build {nrow(retail_parcels)} parcel assignments if geometry was available")
  }
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
})

message("=== Table 2: retail_intensity_by_tract ===")
tryCatch({
  message("⚠ Skipped: Depends on retail_parcel_tract_assignment (needs geometry)")
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
})

message("=== Table 3: parcel_zone_overlay ===")
tryCatch({
  message("⚠ Skipped: Depends on retail_intensity_by_tract (needs geometry)")
  message("")
}, error = function(e) {
  message(glue("✗ Error: {e$message}\n"))
})

message("=== Data Quality Summary ===")
message(glue("Market: {profile$market_key}"))
message(glue("Counties in market: {nrow(parcel_join_qa)}"))
message(glue("Total parcels: {DBI::dbGetQuery(con, paste0('SELECT COUNT(*) FROM parcel.parcels_canonical WHERE market_key = ', DBI::dbQuoteString(con, profile$market_key)))[1,1]}"))
message(glue("Retail parcels: {sum(DBI::dbGetQuery(con, paste0('SELECT retail_flag FROM parcel.parcels_canonical WHERE market_key = ', DBI::dbQuoteString(con, profile$market_key)))$retail_flag, na.rm=TRUE)}"))
message("")

# Check land_use_mapping for retail flags
message("=== Land Use Code Analysis ===")
retail_codes <- DBI::dbGetQuery(con, "
  SELECT COUNT(*) as count_retail_codes
  FROM ref.land_use_mapping
  WHERE retail_flag = TRUE
")
message(glue("Land use codes marked as retail: {retail_codes[1,1]}"))

all_codes <- DBI::dbGetQuery(con, "
  SELECT COUNT(*) as count_all_codes
  FROM ref.land_use_mapping
")
message(glue("Total land use codes: {all_codes[1,1]}")  )
message("")

message("=== Next Steps ===")
message("1. Check if ref.land_use_mapping has correct retail_flag values")
message("2. If not, update the mapping table with correct retail classifications")
message("3. Re-run Layer 04 to regenerate parcel.parcels_canonical with correct retail_flags")
message("4. Once retail parcels exist, parcel geometry files can be built from Layer 04 county outputs")
