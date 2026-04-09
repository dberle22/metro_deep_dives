source("notebooks/retail_opportunity_finder/data_platform/layers/00_reference_membership/reference_membership_workflow.R")

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

ensure_rof_duckdb_schemas(con)
products <- build_reference_membership_products(con)
publish_counts <- publish_reference_membership_products(con, products)

message(
  "Reference layer complete: ",
  publish_counts$market_profiles, " market profiles, ",
  publish_counts$market_cbsa_membership, " market-CBSA membership rows, ",
  publish_counts$market_county_membership, " market-county membership rows, ",
  publish_counts$county_dim, " county dim rows, ",
  publish_counts$tract_dim, " tract dim rows, ",
  publish_counts$land_use_mapping, " land use mapping rows, ",
  publish_counts$qa_validation_results, " QA validation rows, ",
  publish_counts$qa_geography_coverage, " geography coverage rows, ",
  publish_counts$qa_unmapped_land_use_codes, " unmapped candidate land-use rows."
)
