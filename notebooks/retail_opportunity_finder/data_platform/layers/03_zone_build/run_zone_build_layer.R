source("notebooks/retail_opportunity_finder/data_platform/layers/02_tract_scoring/tract_scoring_workflow.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/zone_build_workflow.R")

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

ensure_rof_duckdb_schemas(con)
scoring_products <- build_tract_scoring_products(con)
publish_tract_scoring_products(con, scoring_products)

zone_inputs_bundle <- build_zone_input_candidates(
  scoring_products$scored_tracts,
  scoring_products$tract_sf,
  scoring_products$tract_component_scores,
  scoring_products$cluster_seed_tracts
)

if (!isTRUE(zone_inputs_bundle$readiness_report$pass)) {
  stop("Zone input readiness checks failed; aborting zone-build publication.", call. = FALSE)
}

contiguity_products <- build_contiguity_zone_products(zone_inputs_bundle$eligible_zone_inputs)
cluster_products <- build_cluster_zone_products(zone_inputs_bundle$eligible_zone_inputs)
publish_counts <- publish_zone_build_products(
  con,
  zone_inputs_bundle$eligible_zone_inputs,
  contiguity_products,
  cluster_products,
  profile = scoring_products$profile
)

message(
  "Zone build layer complete for ",
  scoring_products$profile$market_key,
  ": ",
  publish_counts$zone_input_candidates,
  " candidate tracts, ",
  publish_counts$contiguity_zones,
  " contiguity zones, ",
  publish_counts$cluster_zones,
  " cluster zones."
)
