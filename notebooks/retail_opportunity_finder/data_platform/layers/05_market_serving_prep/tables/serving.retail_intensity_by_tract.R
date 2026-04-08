# serving.retail_intensity_by_tract.R
# Purpose: Calculate retail parcel density and intensity metrics at the tract level
# Grain: one row per market_key, tract_geoid
# Dependencies: serving.retail_parcel_tract_assignment, foundation.market_tract_geometry

build_retail_intensity_by_tract <- function(parcel_assignment, tract_sf, profile) {
  tract_sf_area <- normalize_for_spatial_ops(tract_sf, "tract_sf_for_area")
  tract_area_sqmi <- as.numeric(sf::st_area(tract_sf_area)) / 2589988.110336
  tract_land_area <- tract_sf_area %>%
    sf::st_drop_geometry() %>%
    transmute(
      tract_geoid,
      county_geoid,
      tract_land_area_sqmi = tract_area_sqmi
    )

  retail_intensity <- parcel_assignment %>%
    filter(assignment_status == "assigned", !is.na(tract_geoid)) %>%
    group_by(tract_geoid) %>%
    summarise(
      retail_parcel_count = dplyr::n_distinct(parcel_uid),
      retail_area = sum(parcel_area_sqmi, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    right_join(tract_land_area, by = "tract_geoid") %>%
    mutate(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      retail_parcel_count = dplyr::coalesce(retail_parcel_count, 0L),
      retail_area = dplyr::coalesce(retail_area, 0),
      retail_area_density = dplyr::if_else(
        !is.na(tract_land_area_sqmi) & tract_land_area_sqmi > 0,
        retail_area / tract_land_area_sqmi,
        NA_real_
      ),
      pctl_tract_retail_parcel_count = safe_percent_rank(retail_parcel_count),
      pctl_tract_retail_area_density = safe_percent_rank(retail_area_density),
      local_retail_context_score = 0.5 * pctl_tract_retail_parcel_count + 0.5 * pctl_tract_retail_area_density,
      build_source = "data_platform/layers/05_market_serving_prep/tables/serving.retail_intensity_by_tract.R",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      county_geoid,
      tract_geoid,
      tract_land_area_sqmi,
      retail_parcel_count,
      retail_area,
      retail_area_density,
      pctl_tract_retail_parcel_count,
      pctl_tract_retail_area_density,
      local_retail_context_score,
      build_source,
      run_timestamp
    ) %>%
    arrange(tract_geoid)

  retail_intensity
}