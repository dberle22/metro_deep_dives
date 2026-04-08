source("notebooks/retail_opportunity_finder/data_platform/layers/02_tract_scoring/tract_scoring_workflow.R")

con <- connect_project_duckdb(read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

ensure_rof_duckdb_schemas(con)
publications <- build_tract_scoring_layer_publications(con)
qa <- validate_tract_scoring_layer_publications(publications)

if (!isTRUE(qa$pass)) {
  stop("Tract scoring layer QA failed; aborting publication.", call. = FALSE)
}

publish_counts <- publish_tract_scoring_layer_publications(con, publications)

message(
  "Tract scoring layer complete across ",
  publish_counts$markets,
  " markets / ",
  publish_counts$cbsas,
  " CBSAs: ",
  publish_counts$tract_scores,
  " tract score rows and ",
  publish_counts$cluster_seed_tracts,
  " cluster seed rows published."
)

message(
  "Layer 02 QA checks passed: scoring remains market-scoped, one CBSA per market, and cluster seed counts match the configured share for every market."
)
