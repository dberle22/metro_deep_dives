build_parcel_validation_results <- function(products) {
  canonical_unique <- validate_unique_key(products$parcels_canonical, "parcel_uid", "parcel.parcels_canonical")
  missing_join_key_count <- sum(products$parcels_canonical$qa_missing_join_key, na.rm = TRUE)
  missing_county_geoid_count <- sum(is.na(products$parcels_canonical$county_geoid) | !nzchar(products$parcels_canonical$county_geoid))
  join_qa_missing_counties <- sum(is.na(products$parcel_join_qa$analysis_path) | !nzchar(products$parcel_join_qa$analysis_path))
  join_qa_failed_counties <- sum(products$parcel_join_qa$pass == FALSE, na.rm = TRUE)
  join_qa_high_unmatched <- sum(
    !is.na(products$parcel_join_qa$unmatched_rate_analysis) &
      products$parcel_join_qa$unmatched_rate_analysis > 0.02,
    na.rm = TRUE
  )
  zero_parcel_counties <- sum(products$parcel_lineage$distinct_parcels == 0, na.rm = TRUE)

  dplyr::bind_rows(
    make_validation_row(
      "parcel_canonical_unique_parcel_uid",
      dataset = "parcel.parcels_canonical",
      metric_value = canonical_unique$duplicates,
      pass = isTRUE(canonical_unique$pass),
      details = paste("Duplicate parcel_uid rows:", canonical_unique$duplicates)
    ),
    make_validation_row(
      "parcel_canonical_missing_join_key",
      dataset = "parcel.parcels_canonical",
      metric_value = missing_join_key_count,
      pass = missing_join_key_count == 0,
      details = paste("Rows with missing join_key:", missing_join_key_count)
    ),
    make_validation_row(
      "parcel_canonical_missing_county_geoid",
      dataset = "parcel.parcels_canonical",
      metric_value = missing_county_geoid_count,
      pass = missing_county_geoid_count == 0,
      details = paste("Rows with missing county_geoid:", missing_county_geoid_count)
    ),
    make_validation_row(
      "parcel_land_use_mapping_unmapped_codes",
      dataset = "parcel.retail_parcels",
      metric_value = nrow(products$qa_unmapped_use_codes),
      pass = nrow(products$qa_unmapped_use_codes) == 0,
      details = paste("Distinct unmapped land_use_code values:", nrow(products$qa_unmapped_use_codes))
    ),
    make_validation_row(
      "parcel_join_qa_missing_counties",
      dataset = "parcel.parcel_join_qa",
      metric_value = join_qa_missing_counties,
      pass = join_qa_missing_counties == 0,
      details = paste("Parcel-backed market counties without geometry QA lineage:", join_qa_missing_counties)
    ),
    make_validation_row(
      "parcel_join_qa_failed_counties",
      dataset = "parcel.parcel_join_qa",
      metric_value = join_qa_failed_counties,
      pass = join_qa_failed_counties == 0,
      details = paste("Counties with geometry QA pass == FALSE:", join_qa_failed_counties)
    ),
    make_validation_row(
      "parcel_join_qa_high_unmatched_rate_counties",
      severity = "warning",
      dataset = "parcel.parcel_join_qa",
      metric_value = join_qa_high_unmatched,
      pass = join_qa_high_unmatched == 0,
      details = paste("Counties with unmatched_rate_analysis > 0.02:", join_qa_high_unmatched)
    ),
    make_validation_row(
      "parcel_lineage_zero_parcel_counties",
      severity = "warning",
      dataset = "parcel.parcel_lineage",
      metric_value = zero_parcel_counties,
      pass = zero_parcel_counties == 0,
      details = paste("Parcel-backed market counties with zero published parcels:", zero_parcel_counties)
    )
  ) %>%
    mutate(
      build_source = "data_platform/layers/04_parcel_standardization",
      run_timestamp = as.character(Sys.time())
    )
}
