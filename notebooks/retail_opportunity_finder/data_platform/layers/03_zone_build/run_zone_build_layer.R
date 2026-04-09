source("notebooks/retail_opportunity_finder/data_platform/layers/02_tract_scoring/tract_scoring_workflow.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/zone_build_workflow.R")

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

ensure_rof_duckdb_schemas(con)
publications <- build_zone_build_layer_publications(con)
qa <- validate_zone_build_layer_publications(publications)

if (!isTRUE(qa$pass)) {
  stop("Zone build layer QA failed; aborting publication.", call. = FALSE)
}

publish_counts <- publish_zone_build_layer_publications(con, publications)

message(
  "Zone build layer complete across ",
  publish_counts$markets,
  " markets / ",
  publish_counts$cbsas,
  " CBSAs: ",
  publish_counts$zone_input_candidates,
  " candidate tracts, ",
  publish_counts$contiguity_zone_summary,
  " contiguity zones, ",
  publish_counts$cluster_zone_summary,
  " cluster zones."
)

message(
  "Layer 03 QA checks passed: multi-market publication present, one CBSA per market, and no duplicate grain keys across the published zone tables."
)

message(
  "Layer 03 published ",
  publish_counts$qa_validation_results,
  " zone-build QA rows and ",
  publish_counts$qa_skipped_markets,
  " skipped-market QA rows."
)

if (qa$skipped_market_count > 0) {
  skipped_labels <- qa$skipped_markets %>%
    mutate(label = paste0(market_key, " (", cbsa_code, ")")) %>%
    pull(label)

  message(
    "Layer 03 skipped ",
    qa$skipped_market_count,
    " market(s) that failed zone-input readiness checks: ",
    paste(skipped_labels, collapse = ", "),
    "."
  )
}
