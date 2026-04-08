build_parcel_lineage <- function(market_counties, geometry_join_qa, load_log, parcels_canonical) {
  parcel_counts <- parcels_canonical %>%
    group_by(market_key, county_geoid, county_fips) %>%
    summarise(
      parcel_rows = n(),
      distinct_parcels = n_distinct(parcel_uid),
      .groups = "drop"
    )

  county_lineage_base <- if (nrow(geometry_join_qa) == 0) {
    market_counties %>%
      transmute(
        market_key,
        cbsa_code,
        state_abbr,
        state_fips,
        county_fips,
        county_geoid,
        county_name,
        county_tag,
        county_name_key,
        source_county_tag = NA_character_,
        source_county_code = NA_character_,
        source_shp = NA_character_,
        output_dir = NA_character_,
        raw_path = NA_character_,
        analysis_path = NA_character_,
        qa_path = NA_character_,
        total_rows_raw = NA_real_,
        unmatched_rows_raw = NA_real_,
        unmatched_rate_raw = NA_real_,
        total_rows_analysis = NA_real_,
        unmatched_rows_analysis = NA_real_,
        unmatched_rate_analysis = NA_real_,
        pass = NA
      )
  } else {
    market_counties %>%
      left_join(
        geometry_join_qa %>%
          select(
            county_name_key,
            source_county_tag = county_tag,
            source_county_code = county_code,
            source_shp,
            output_dir,
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
          ),
        by = "county_name_key"
      )
  }

  county_lineage_base %>%
    left_join(parcel_counts, by = c("market_key", "county_geoid", "county_fips")) %>%
    left_join(load_log, by = c("state_abbr", "county_name_key")) %>%
    mutate(
      county_fips = dplyr::coalesce(.data$county_fips.x, .data$county_fips.y),
      county_tag = dplyr::coalesce(.data$county_tag.x, .data$county_tag.y),
      county_name = dplyr::coalesce(.data$county_name.x, .data$county_name.y),
      source_file = dplyr::coalesce(.data$source_file, NA_character_),
      source_shp = dplyr::coalesce(.data$source_shp.x, .data$source_shp.y),
      raw_path = dplyr::coalesce(.data$raw_path.x, .data$raw_path.y),
      analysis_path = dplyr::coalesce(.data$analysis_path.x, .data$analysis_path.y),
      qa_path = dplyr::coalesce(.data$qa_path.x, .data$qa_path.y),
      total_rows_raw = dplyr::coalesce(.data$total_rows_raw.x, .data$total_rows_raw.y),
      unmatched_rows_raw = dplyr::coalesce(.data$unmatched_rows_raw.x, .data$unmatched_rows_raw.y),
      unmatched_rate_raw = dplyr::coalesce(.data$unmatched_rate_raw.x, .data$unmatched_rate_raw.y),
      total_rows_analysis = dplyr::coalesce(.data$total_rows_analysis.x, .data$total_rows_analysis.y),
      unmatched_rows_analysis = dplyr::coalesce(.data$unmatched_rows_analysis.x, .data$unmatched_rows_analysis.y),
      unmatched_rate_analysis = dplyr::coalesce(.data$unmatched_rate_analysis.x, .data$unmatched_rate_analysis.y),
      pass = dplyr::coalesce(.data$pass.x, .data$pass.y),
      parcel_rows = dplyr::coalesce(parcel_rows, 0L),
      distinct_parcels = dplyr::coalesce(distinct_parcels, 0L),
      lineage_source = dplyr::case_when(
        !is.na(load_status) ~ "rof_parcel.parcel_county_load_log + parcel_geometry_join_qa_county_summary.rds",
        !is.na(analysis_path) ~ "parcel_geometry_join_qa_county_summary.rds",
        TRUE ~ "market_counties_only"
      ),
      build_source = "ref.market_county_membership + parcel geometry QA + county load log + parcel counts",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      state_abbr,
      state_fips,
      county_fips,
      county_geoid,
      county_name,
      county_tag,
      source_file,
      source_shp,
      source_shp_path,
      raw_path,
      analysis_keep_duplicates_path,
      analysis_path,
      qa_path,
      transform_version,
      generated_at,
      load_completed_at,
      load_status,
      load_note,
      parcel_rows,
      distinct_parcels,
      duplicate_groups,
      duplicate_rows,
      dissolve_fallback_rows,
      total_rows_raw,
      unmatched_rows_raw,
      unmatched_rate_raw,
      total_rows_analysis,
      unmatched_rows_analysis,
      unmatched_rate_analysis,
      pass,
      lineage_source,
      build_source,
      run_timestamp
    ) %>%
    arrange(market_key, county_geoid)
}
