# Section 03 checks script
# Purpose: sanity checks and QA assertions for section outputs.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 03 checks: 03_eligibility_scoring")

funnel_counts <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_funnel_counts.rds")
eligible_tracts <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_eligible_tracts.rds")
scored_tracts <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_scored_tracts.rds")
top_tracts <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_top_tracts.rds")
tract_component_scores <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_tract_component_scores.rds")
tract_sf <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_tract_sf.rds")

funnel_check <- validate_columns(
  funnel_counts,
  c("step", "step_order", "tracts_remaining"),
  "section_03_funnel_counts"
)
eligible_check <- validate_columns(
  eligible_tracts,
  c("tract_geoid", "eligible_v1", "growth_raw", "units_raw", "headroom_raw", "price_raw", "commute_raw"),
  "section_03_eligible_tracts"
)
scored_check <- validate_columns(
  scored_tracts,
  c(
    "tract_geoid", "tract_rank", "tract_score", "z_growth", "z_units", "z_headroom",
    "z_price", "z_commute", "contrib_growth", "contrib_units", "contrib_headroom",
    "contrib_price", "contrib_commute", "why_tags"
  ),
  "section_03_scored_tracts"
)
top_check <- validate_columns(
  top_tracts,
  c("tract_rank", "tract_geoid", "tract_score", "why_tags"),
  "section_03_top_tracts"
)
component_table_check <- validate_columns(
  tract_component_scores,
  c(
    "tract_geoid", "eligible_v1", "gate_pop", "gate_price", "gate_density",
    "z_growth", "z_units", "z_headroom", "z_price", "z_commute",
    "contrib_growth", "contrib_units", "contrib_headroom", "contrib_price", "contrib_commute",
    "tract_score", "tract_rank", "why_tags", "is_scored"
  ),
  "section_03_tract_component_scores"
)
geometry_check <- validate_sf(tract_sf, "section_03_tract_sf", GEOMETRY_ASSUMPTIONS$expected_crs_epsg)

logic_checks <- list(
  funnel_monotonic = all(diff(funnel_counts$tracts_remaining) <= 0),
  eligible_subset_correct = all(eligible_tracts$eligible_v1 == 1),
  scored_subset_correct = all(scored_tracts$eligible_v1 == 1),
  scores_finite = all(is.finite(scored_tracts$tract_score)),
  score_rank_unique = nrow(scored_tracts) == dplyr::n_distinct(scored_tracts$tract_rank),
  score_rank_sequential = identical(sort(scored_tracts$tract_rank), seq_len(nrow(scored_tracts))),
  top_n_cap = nrow(top_tracts) <= MODEL_PARAMS$top_n_tracts,
  component_row_count_matches = nrow(tract_component_scores) >= nrow(scored_tracts),
  component_score_populated_for_scored = all(
    tract_component_scores %>%
      filter(is_scored) %>%
      pull(tract_score) %>%
      is.finite()
  ),
  qa_eligible_count_matches_funnel = sum(tract_component_scores$eligible_v1 == 1, na.rm = TRUE) ==
    funnel_counts %>% filter(step == "Eligible (v1)") %>% pull(tracts_remaining)
)

report <- list(
  run_metadata = run_metadata(),
  checks = list(
    funnel_check = funnel_check,
    eligible_check = eligible_check,
    scored_check = scored_check,
    top_check = top_check,
    component_table_check = component_table_check,
    geometry_check = geometry_check
  ),
  logic_checks = logic_checks
)

save_artifact(
  report,
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_validation_report.rds"
)

schema_pass <- all(vapply(report$checks[1:5], `[[`, logical(1), "pass")) && isTRUE(report$checks$geometry_check$pass)
logic_pass <- all(unlist(logic_checks))

if (!schema_pass || !logic_pass) {
  stop("Section 03 checks failed. See section_03_validation_report.rds for details.", call. = FALSE)
}

message("Section 03 checks complete.")
