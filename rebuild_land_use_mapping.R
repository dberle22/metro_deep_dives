#!/usr/bin/env Rscript
# Rebuild just the land_use_mapping table

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

library(DBI)
library(duckdb)
library(dplyr)

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

# Load the build function
source("notebooks/retail_opportunity_finder/data_platform/layers/00_reference_membership/reference_membership_workflow.R")

message("=== Rebuilding ref.land_use_mapping ===\n")

ensure_rof_duckdb_schemas(con)

# Build the land_use_mapping
land_use_mapping <- build_ref_land_use_mapping()
message(glue("Built {nrow(land_use_mapping)} land use mappings"))

# Publish it
write_duckdb_table(con, "ref", "land_use_mapping", land_use_mapping, overwrite = TRUE)
message("Published to database\n")

# Verify it
retail_count <- land_use_mapping %>% filter(retail_flag == TRUE) %>% nrow()
non_retail_count <- land_use_mapping %>% filter(retail_flag == FALSE) %>% nrow()

message(glue("Retail codes: {retail_count}"))
message(glue("Non-retail codes: {non_retail_count}"))
message("")

# Show sample of retail codes
message("Sample retail codes:")
print(land_use_mapping %>% filter(retail_flag == TRUE) %>% select(land_use_code, category, description, retail_subtype, mapping_method) %>% head(10))
