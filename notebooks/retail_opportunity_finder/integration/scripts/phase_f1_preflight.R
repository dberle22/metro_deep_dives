#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(readr)
})

artifact_paths <- c(
  # Section 02
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_visual_objects.rds",
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_validation_report.rds",
  # Section 03
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_funnel_counts.rds",
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_scored_tracts.rds",
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_top_tracts.rds",
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_visual_objects.rds",
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_validation_report.rds",
  # Section 04
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_zone_summary.rds",
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_visual_objects.rds",
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_zone_summary.rds",
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_visual_objects.rds",
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_vs_contiguity_comparison.rds",
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_validation_report.rds",
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_validation_report.rds",
  # Section 05
  "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_zone_overlay_contiguity.rds",
  "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_zone_overlay_cluster.rds",
  "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_parcel_shortlist_contiguity.rds",
  "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_parcel_shortlist_cluster.rds",
  "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_visual_objects.rds",
  "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_validation_report.rds",
  # Section 06
  "notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/outputs/section_06_conclusion_payload.rds",
  "notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/outputs/section_06_appendix_payload.rds",
  "notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/outputs/section_06_visual_objects.rds",
  "notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/outputs/section_06_validation_report.rds"
)

artifact_status <- tibble(
  artifact_path = artifact_paths,
  exists = file.exists(artifact_paths)
)

pass_eval <- function(section, report_path) {
  if (!file.exists(report_path)) {
    return(tibble(section = section, report_path = report_path, pass = FALSE, warning_count = NA_integer_, note = "missing report"))
  }

  x <- readRDS(report_path)

  if (section == "section_03") {
    pass <- all(vapply(x$checks[1:5], function(y) isTRUE(y$pass), logical(1))) &&
      isTRUE(x$checks$geometry_check$pass) &&
      all(unlist(x$logic_checks))
    warning_count <- 0L
  } else if (section == "section_02") {
    pass <- all(vapply(x$checks, function(y) isTRUE(y$pass), logical(1))) && all(unlist(x$logic_checks))
    warning_count <- 0L
  } else {
    pass <- isTRUE(x$pass)
    warning_count <- if (!is.null(x$warnings)) length(x$warnings) else 0L
  }

  tibble(
    section = section,
    report_path = report_path,
    pass = pass,
    warning_count = warning_count,
    note = "ok"
  )
}

validation_status <- bind_rows(
  pass_eval("section_02", "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_validation_report.rds"),
  pass_eval("section_03", "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_validation_report.rds"),
  pass_eval("section_04", "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_validation_report.rds"),
  pass_eval("section_04_cluster", "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_validation_report.rds"),
  pass_eval("section_05", "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_validation_report.rds"),
  pass_eval("section_06", "notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/outputs/section_06_validation_report.rds")
)

preflight_summary <- list(
  run_timestamp = as.character(Sys.time()),
  artifact_checks = artifact_status,
  validation_status = validation_status,
  artifacts_all_present = all(artifact_status$exists),
  sections_all_pass = all(validation_status$pass)
)

if (!dir.exists("notebooks/retail_opportunity_finder/integration/outputs")) {
  dir.create("notebooks/retail_opportunity_finder/integration/outputs", recursive = TRUE)
}

write_csv(artifact_status, "notebooks/retail_opportunity_finder/integration/outputs/phase_f1_required_artifact_status.csv")
write_csv(validation_status, "notebooks/retail_opportunity_finder/integration/outputs/phase_f1_validation_status.csv")
saveRDS(preflight_summary, "notebooks/retail_opportunity_finder/integration/outputs/phase_f1_preflight_summary.rds")

if (!preflight_summary$artifacts_all_present || !preflight_summary$sections_all_pass) {
  stop("Phase F1 preflight failed. See integration/outputs phase_f1_* outputs.", call. = FALSE)
}

cat("Phase F1 preflight passed.\n")
