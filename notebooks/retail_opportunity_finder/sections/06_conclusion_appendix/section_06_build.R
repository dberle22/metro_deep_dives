# Section 06 build script
# Purpose: data prep and core transformations for section 06_conclusion_appendix.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 06 build: 06_conclusion_appendix")

required_paths <- c(
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_top_tracts.rds",
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_validation_report.rds",
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_zone_summary.rds",
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_zone_summary.rds",
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_validation_report.rds",
  "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_zone_overlay_cluster.rds",
  "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_parcel_shortlist_cluster.rds",
  "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_validation_report.rds"
)
missing_paths <- required_paths[!file.exists(required_paths)]
if (length(missing_paths) > 0) {
  stop(
    glue::glue("Section 06 build missing required inputs: {paste(missing_paths, collapse = '; ')}"),
    call. = FALSE
  )
}

top_tracts <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_top_tracts.rds")
zone_summary <- readRDS("notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_zone_summary.rds")
cluster_zone_summary <- readRDS("notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_zone_summary.rds")
zone_overlay_cluster <- readRDS("notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_zone_overlay_cluster.rds")
parcel_shortlist_cluster <- readRDS("notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_parcel_shortlist_cluster.rds")

section_03_report <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_validation_report.rds")
section_04_report <- readRDS("notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_validation_report.rds")
section_05_report <- readRDS("notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_validation_report.rds")

or_else <- function(x, fallback) if (is.null(x)) fallback else x

cluster_zone_highlights <- zone_overlay_cluster %>%
  arrange(desc(zone_quality_score), desc(retail_parcel_count)) %>%
  slice_head(n = 3) %>%
  select(
    zone_id,
    zone_label,
    tracts,
    retail_parcel_count,
    retail_area_density,
    zone_quality_score
  )

shortlist_summary <- parcel_shortlist_cluster %>%
  sf::st_drop_geometry() %>%
  summarise(
    n_shortlisted = n(),
    n_zones = n_distinct(zone_id),
    median_shortlist_score = median(shortlist_score, na.rm = TRUE),
    p90_shortlist_score = quantile(shortlist_score, 0.90, na.rm = TRUE),
    median_parcel_area_sqmi = median(parcel_area_sqmi, na.rm = TRUE),
    median_assessed_value = median(assessed_value, na.rm = TRUE)
  )

top_shortlist_preview <- parcel_shortlist_cluster %>%
  sf::st_drop_geometry() %>%
  arrange(shortlist_rank_system) %>%
  slice_head(n = 15) %>%
  select(
    shortlist_rank_system,
    zone_label,
    parcel_uid,
    shortlist_score,
    zone_quality_score,
    local_retail_context_score,
    parcel_characteristics_score
  )

recommended_next_actions <- c(
  "Prioritize field validation in top-ranked cluster zones before site-level underwriting.",
  "Review parcel shortlist candidates with invalid geometries and repair before downstream mapping/export.",
  "Run boundary sensitivity analysis (strict in-zone vs buffered assignment) before production release.",
  "Calibrate shortlist score weights with stakeholder feedback and overlap diagnostics."
)

conclusion_payload <- list(
  run_metadata = run_metadata(),
  highlights = list(
    cluster_zone_highlights = cluster_zone_highlights,
    shortlist_summary = shortlist_summary,
    top_shortlist_preview = top_shortlist_preview
  ),
  recommendations = recommended_next_actions
)

qa_summary <- tibble::tibble(
  section = c("section_03", "section_04", "section_05"),
  report_path = c(
    "sections/03_eligibility_scoring/outputs/section_03_validation_report.rds",
    "sections/04_zones/outputs/section_04_validation_report.rds",
    "sections/05_parcels/outputs/section_05_validation_report.rds"
  ),
  pass = c(
    isTRUE(or_else(section_03_report$pass, (all(vapply(section_03_report$checks[1:5], `[[`, logical(1), "pass")) && all(unlist(section_03_report$logic_checks))))),
    isTRUE(section_04_report$pass),
    isTRUE(section_05_report$pass)
  ),
  warning_count = c(
    0L,
    length(or_else(section_04_report$warnings, character())),
    length(or_else(section_05_report$warnings, character()))
  )
)

assumptions_caveats <- tibble::tibble(
  category = c(
    "Data coverage",
    "Spatial assignment policy",
    "CRS policy",
    "Scoring calibration",
    "Geometry quality",
    "Interpretation"
  ),
  statement = c(
    "Parcel standardization currently reflects available county outputs in the configured Florida scope.",
    "Sprint D shortlist uses strict in-zone parcel assignment (no buffer sensitivity in baseline).",
    "Storage CRS is EPSG:4326; spatial operations are normalized to analysis CRS EPSG:5070.",
    "Section 05 shortlist weights are v0.1 defaults and require future sensitivity testing.",
    "Some shortlisted parcel geometries remain invalid and are flagged for follow-up repair.",
    "Shortlist output is screening-oriented and should be followed by site-level diligence."
  )
)

appendix_payload <- list(
  run_metadata = run_metadata(),
  kpi_dictionary = KPI_DICTIONARY,
  assumptions_caveats = assumptions_caveats,
  qa_summary = qa_summary,
  section_06_input_snapshot = list(
    top_tract_rows = nrow(top_tracts),
    contiguity_zone_rows = nrow(zone_summary),
    cluster_zone_rows = nrow(cluster_zone_summary),
    cluster_shortlist_rows = nrow(parcel_shortlist_cluster)
  )
)

save_artifact(
  conclusion_payload,
  "notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/outputs/section_06_conclusion_payload.rds"
)
save_artifact(
  appendix_payload,
  "notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/outputs/section_06_appendix_payload.rds"
)

message("Section 06 build complete.")
