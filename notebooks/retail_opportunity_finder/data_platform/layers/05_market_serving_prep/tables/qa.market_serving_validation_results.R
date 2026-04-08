# qa.market_serving_validation_results.R
# Purpose: QA validation checks for market serving data quality
# Grain: one row per check_name, dataset, market_key
# Dependencies: All serving tables

build_market_serving_qa <- function(products, profile) {
  assignment_unassigned <- sum(products$retail_parcel_tract_assignment$assignment_status != "assigned", na.rm = TRUE)
  missing_geometry <- sum(is.na(sf::st_geometry(products$retail_parcels_sf)))
  intensity_dupes <- nrow(products$retail_intensity_by_tract) - dplyr::n_distinct(products$retail_intensity_by_tract$tract_geoid)
  overlay_dupes <- nrow(products$parcel_zone_overlay) - dplyr::n_distinct(paste(products$parcel_zone_overlay$zone_system, products$parcel_zone_overlay$zone_id, sep = "::"))
  shortlist_dupes <- if (!is.null(products$parcel_shortlist) && nrow(products$parcel_shortlist) > 0) {
    nrow(products$parcel_shortlist) - dplyr::n_distinct(paste(products$parcel_shortlist$zone_system, products$parcel_shortlist$parcel_uid, sep = "::"))
  } else {
    0L
  }
  shortlist_missing_score <- if (!is.null(products$parcel_shortlist) && nrow(products$parcel_shortlist) > 0 && "shortlist_score" %in% names(products$parcel_shortlist)) {
    sum(is.na(products$parcel_shortlist$shortlist_score), na.rm = TRUE)
  } else {
    0L
  }

  dplyr::bind_rows(
    make_validation_row(
      "serving_retail_parcel_missing_geometry",
      dataset = "serving.retail_parcel_tract_assignment",
      metric_value = missing_geometry,
      pass = missing_geometry == 0,
      details = paste("Retail parcels without geometry after .RDS join:", missing_geometry)
    ),
    make_validation_row(
      "serving_tract_assignment_unassigned_parcels",
      severity = "warning",
      dataset = "serving.retail_parcel_tract_assignment",
      metric_value = assignment_unassigned,
      pass = assignment_unassigned == 0,
      details = paste("Retail parcels without tract assignment:", assignment_unassigned)
    ),
    make_validation_row(
      "serving_retail_intensity_unique_tract",
      dataset = "serving.retail_intensity_by_tract",
      metric_value = intensity_dupes,
      pass = intensity_dupes == 0,
      details = paste("Duplicate tract rows in retail intensity:", intensity_dupes)
    ),
    make_validation_row(
      "serving_zone_overlay_unique_zone",
      dataset = "serving.parcel_zone_overlay",
      metric_value = overlay_dupes,
      pass = overlay_dupes == 0,
      details = paste("Duplicate zone rows in parcel zone overlay:", overlay_dupes)
    ),
    make_validation_row(
      "serving_shortlist_unique_zone_parcel",
      dataset = "serving.parcel_shortlist",
      metric_value = shortlist_dupes,
      pass = shortlist_dupes == 0,
      details = paste("Duplicate zone-system parcel rows in shortlist:", shortlist_dupes)
    ),
    make_validation_row(
      "serving_shortlist_missing_scores",
      severity = "warning",
      dataset = "serving.parcel_shortlist",
      metric_value = shortlist_missing_score,
      pass = shortlist_missing_score == 0,
      details = paste("Shortlist rows with missing shortlist_score:", shortlist_missing_score)
    )
  ) %>%
    mutate(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      build_source = "data_platform/layers/05_market_serving_prep/tables/qa.market_serving_validation_results.R",
      run_timestamp = as.character(Sys.time())
    )
}