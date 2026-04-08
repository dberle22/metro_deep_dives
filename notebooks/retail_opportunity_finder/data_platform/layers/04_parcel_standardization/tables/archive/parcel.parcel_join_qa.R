build_parcel_join_qa <- function(parcel_lineage) {
  parcel_lineage %>%
    transmute(
      market_key,
      cbsa_code,
      state_abbr,
      state_fips,
      county_fips,
      county_geoid,
      county_name,
      county_tag,
      source_shp,
      output_dir = NA_character_,
      raw_path,
      analysis_path,
      qa_path,
      total_rows_raw,
      unmatched_rows_raw,
      unmatched_rate_raw,
      total_rows_analysis,
      unmatched_rows_analysis,
      unmatched_rate_analysis,
      pass
    ) %>%
    mutate(
      build_source = "parcel.parcel_lineage compatibility projection",
      run_timestamp = as.character(Sys.time())
    ) %>%
    arrange(county_geoid)
}
