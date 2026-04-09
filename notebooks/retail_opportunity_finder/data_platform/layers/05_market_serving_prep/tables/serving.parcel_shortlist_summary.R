# serving.parcel_shortlist_summary.R
# Purpose: Summarize shortlist statistics and quality metrics by zone
# Grain: one row per market_key, zone_system, zone_id
# Dependencies: serving.parcel_shortlist

build_parcel_shortlist_summary <- function(parcel_shortlist, profile) {
  parcel_shortlist %>%
    group_by(zone_system, zone_id, zone_label) %>%
    summarise(
      shortlisted_parcels = dplyr::n_distinct(parcel_uid),
      top_shortlist_score = max(shortlist_score, na.rm = TRUE),
      mean_shortlist_score = mean(shortlist_score, na.rm = TRUE),
      median_parcel_area_sqmi = median(parcel_area_sqmi, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      build_source = "data_platform/layers/05_market_serving_prep/tables/serving.parcel_shortlist_summary.R",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      zone_system,
      zone_id,
      zone_label,
      shortlisted_parcels,
      top_shortlist_score,
      mean_shortlist_score,
      median_parcel_area_sqmi,
      build_source,
      run_timestamp
    ) %>%
    arrange(zone_system, zone_id)
}