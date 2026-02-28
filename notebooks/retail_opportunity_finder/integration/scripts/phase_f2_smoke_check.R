#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(readr)
})

artifact_manifest <- tribble(
  ~alias, ~path,
  "section01_run_metadata", "notebooks/retail_opportunity_finder/sections/01_setup/outputs/section_01_run_metadata.rds",
  "section01_foundation", "notebooks/retail_opportunity_finder/sections/01_setup/outputs/section_01_foundation.rds",
  "section02_visual_objects", "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_visual_objects.rds",
  "section02_validation_report", "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_validation_report.rds",
  "section03_visual_objects", "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_visual_objects.rds",
  "section03_validation_report", "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_validation_report.rds",
  "section04_visual_objects", "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_visual_objects.rds",
  "section04_cluster_visual_objects", "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_visual_objects.rds",
  "section04_validation_report", "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_validation_report.rds",
  "section04_cluster_validation_report", "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_validation_report.rds",
  "section05_visual_objects", "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_visual_objects.rds",
  "section05_validation_report", "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_validation_report.rds",
  "section06_visual_objects", "notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/outputs/section_06_visual_objects.rds",
  "section06_validation_report", "notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/outputs/section_06_validation_report.rds"
)

artifact_status <- artifact_manifest %>% mutate(exists = file.exists(path))
if (any(!artifact_status$exists)) {
  write_csv(artifact_status, "notebooks/retail_opportunity_finder/integration/outputs/phase_f2_artifact_status.csv")
  stop("Phase F2 smoke check failed: missing artifacts.", call. = FALSE)
}

artifacts <- lapply(artifact_manifest$path, readRDS)
names(artifacts) <- artifact_manifest$alias

pass_02 <- with(artifacts$section02_validation_report,
  all(vapply(checks, function(x) isTRUE(x$pass), logical(1))) && all(unlist(logic_checks))
)
pass_03 <- with(artifacts$section03_validation_report,
  all(vapply(checks[1:5], function(x) isTRUE(x$pass), logical(1))) && isTRUE(checks$geometry_check$pass) && all(unlist(logic_checks))
)
pass_04 <- isTRUE(artifacts$section04_validation_report$pass)
pass_04_cluster <- isTRUE(artifacts$section04_cluster_validation_report$pass)
pass_05 <- isTRUE(artifacts$section05_validation_report$pass)
pass_06 <- isTRUE(artifacts$section06_validation_report$pass)

required_visual_keys <- list(
  section02_visual_objects = c("tiles_layout", "peer_gt", "benchmark_gt", "pop_trend_plot", "distribution_plot"),
  section03_visual_objects = c("funnel_gt", "price_hist_plot", "growth_hist_plot", "eligible_map_plot", "score_hist_plot", "growth_density_scatter", "top_tracts_gt"),
  section04_visual_objects = c("zone_map_plot", "zone_summary_gt"),
  section04_cluster_visual_objects = c("cluster_zone_map_plot", "cluster_summary_gt", "comparison_gt"),
  section05_visual_objects = c("overlay_map_contiguity", "overlay_map_cluster", "shortlist_map_contiguity", "shortlist_map_cluster", "shortlist_table_contiguity", "shortlist_table_cluster", "system_comparison_gt"),
  section06_visual_objects = c("conclusion_summary_table", "shortlist_summary_table", "qa_summary_table", "assumptions_caveats_table", "recommendations_table")
)

visual_key_status <- bind_rows(lapply(names(required_visual_keys), function(alias) {
  keys <- names(artifacts[[alias]])
  missing <- setdiff(required_visual_keys[[alias]], keys)
  tibble(
    alias = alias,
    missing_key_count = length(missing),
    missing_keys = if (length(missing) == 0) "" else paste(missing, collapse = "; "),
    pass = length(missing) == 0
  )
}))

validation_status <- tibble(
  section = c("section_02", "section_03", "section_04", "section_04_cluster", "section_05", "section_06"),
  pass = c(pass_02, pass_03, pass_04, pass_04_cluster, pass_05, pass_06)
)

summary <- list(
  run_timestamp = as.character(Sys.time()),
  artifacts_all_present = all(artifact_status$exists),
  validation_all_pass = all(validation_status$pass),
  visual_keys_all_pass = all(visual_key_status$pass),
  note = "F2 scaffold smoke checks use readRDS artifacts only"
)

write_csv(artifact_status, "notebooks/retail_opportunity_finder/integration/outputs/phase_f2_artifact_status.csv")
write_csv(validation_status, "notebooks/retail_opportunity_finder/integration/outputs/phase_f2_validation_status.csv")
write_csv(visual_key_status, "notebooks/retail_opportunity_finder/integration/outputs/phase_f2_visual_key_status.csv")
saveRDS(summary, "notebooks/retail_opportunity_finder/integration/outputs/phase_f2_smoke_summary.rds")

if (!summary$artifacts_all_present || !summary$validation_all_pass || !summary$visual_keys_all_pass) {
  stop("Phase F2 smoke check failed.", call. = FALSE)
}

cat("Phase F2 smoke check passed.\n")
