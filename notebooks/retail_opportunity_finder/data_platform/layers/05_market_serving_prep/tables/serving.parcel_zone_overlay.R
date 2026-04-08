# serving.parcel_zone_overlay.R
# Purpose: Aggregate retail metrics by zone system (contiguity and cluster zones)
# Grain: one row per market_key, zone_system, zone_id
# Dependencies: zones.contiguity_zone_components, zones.cluster_assignments, serving.retail_intensity_by_tract

build_parcel_zone_overlay <- function(zone_assignments, zone_summaries, retail_intensity_by_tract, profile) {
  zone_assignments %>%
    left_join(
      retail_intensity_by_tract %>%
        select(tract_geoid, retail_parcel_count, retail_area, tract_land_area_sqmi, local_retail_context_score),
      by = "tract_geoid"
    ) %>%
    group_by(zone_system, zone_id, zone_label, zone_order) %>%
    summarise(
      tracts = dplyr::n_distinct(tract_geoid),
      retail_parcel_count = sum(retail_parcel_count, na.rm = TRUE),
      retail_area = sum(retail_area, na.rm = TRUE),
      tract_land_area_sqmi = sum(tract_land_area_sqmi, na.rm = TRUE),
      retail_area_density = dplyr::if_else(tract_land_area_sqmi > 0, retail_area / tract_land_area_sqmi, NA_real_),
      local_retail_context_score = mean(local_retail_context_score, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    left_join(
      zone_summaries %>%
        select(zone_system, zone_id, mean_tract_score, zone_quality_score, zone_area_sq_mi, total_population),
      by = c("zone_system", "zone_id")
    ) %>%
    mutate(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      build_source = "data_platform/layers/05_market_serving_prep/tables/serving.parcel_zone_overlay.R",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      zone_system,
      zone_id,
      zone_label,
      zone_order,
      tracts,
      total_population,
      zone_area_sq_mi,
      retail_parcel_count,
      retail_area,
      tract_land_area_sqmi,
      retail_area_density,
      local_retail_context_score,
      mean_tract_score,
      zone_quality_score,
      build_source,
      run_timestamp
    ) %>%
    arrange(zone_system, zone_order)
}