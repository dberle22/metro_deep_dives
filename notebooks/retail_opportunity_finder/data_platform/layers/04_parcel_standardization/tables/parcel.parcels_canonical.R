build_parcels_canonical <- function(con, market_counties = read_parcel_available_market_counties(con)) {
  market_counties_lookup <- market_counties %>%
    transmute(
      market_key,
      cbsa_code,
      state_abbr,
      state_fips,
      county_geoid_ref = county_geoid,
      county_fips_ref = county_fips,
      county_code_ref = county_code,
      county_tag_ref = county_tag,
      county_name_ref = county_name,
      county_name_key
    )

  parcel_tabular <- query_market_parcel_tabular(con, market_counties) %>%
    as_tibble() %>%
    mutate(
      state_abbr_source = toupper(as.character(state)),
      county_geoid_source = as.character(county_geoid),
      county_fips_source = normalize_county_fips(county_fips),
      source_county_code = normalize_county_code(county_code),
      census_block_id = dplyr::na_if(trimws(as.character(census_block_id)), ""),
      join_key = trimws(as.character(join_key)),
      parcel_id = as.character(parcel_id),
      alt_key = as.character(alt_key),
      county_name_source = as.character(county_name),
      county_name_key = normalize_county_name_key(county_name_source),
      land_use_code = normalize_land_use_code(use_code),
      owner_name = as.character(owner_name),
      owner_addr = as.character(owner_addr),
      site_addr = as.character(phys_addr),
      just_value = suppressWarnings(as.numeric(just_value)),
      land_value = suppressWarnings(as.numeric(land_value)),
      impro_value = suppressWarnings(as.numeric(impro_value)),
      total_value = suppressWarnings(as.numeric(total_value)),
      living_area_sqft = suppressWarnings(as.numeric(living_area_sqft)),
      sale_qual_code = as.character(sale_qual_code),
      last_sale_price = suppressWarnings(as.numeric(sale_price1)),
      sale_yr1 = suppressWarnings(as.integer(sale_yr1)),
      sale_mo1 = suppressWarnings(as.integer(sale_mo1)),
      sale_mo1 = dplyr::if_else(!is.na(sale_mo1) & sale_mo1 >= 1L & sale_mo1 <= 12L, sale_mo1, NA_integer_),
      last_sale_date = lubridate::make_date(year = sale_yr1, month = sale_mo1, day = 1L),
      ingest_run_id = NA_character_,
      transform_version = "rof_parcel.parcel_tabular_clean_current",
      qa_missing_join_key = is.na(join_key) | join_key == "",
      qa_zero_county = is.na(source_county_code) | source_county_code == "" | source_county_code == "0",
      source_county_tag = as.character(county_tag),
      parcel_uid = paste0(source_county_code, "::", join_key)
    ) %>%
    semi_join(
      market_counties %>% select(state_abbr, county_name_key) %>% distinct(),
      by = c("state_abbr_source" = "state_abbr", "county_name_key")
    ) %>%
    left_join(
      market_counties_lookup,
      by = c("state_abbr_source" = "state_abbr", "county_name_key")
    ) %>%
    mutate(
      county_geoid = dplyr::coalesce(county_geoid_ref, county_geoid_source),
      county_fips = dplyr::coalesce(county_fips_ref, county_fips_source),
      county_code = dplyr::coalesce(county_code_ref, source_county_code),
      county_tag = dplyr::coalesce(county_tag_ref, derive_county_tag(county_fips)),
      county_name = dplyr::coalesce(county_name_ref, county_name_source),
      state_abbr = state_abbr_source,
      build_source = "rof_parcel.parcel_tabular_clean filtered to parcel-backed ref.market_county_membership counties",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      state_abbr,
      state_fips,
      county_fips,
      county_geoid,
      county_code,
      county_tag,
      county_name,
      county_name_key,
      source_county_code,
      source_county_tag,
      county_name_source,
      source_file,
      ingest_run_id,
      transform_version,
      parcel_uid,
      parcel_id,
      alt_key,
      join_key,
      census_block_id,
      land_use_code,
      owner_name,
      owner_addr,
      site_addr,
      living_area_sqft,
      just_value,
      land_value,
      impro_value,
      total_value,
      sale_qual_code,
      last_sale_price,
      last_sale_date,
      qa_missing_join_key,
      qa_zero_county,
      build_source,
      run_timestamp
    ) %>%
    arrange(market_key, county_geoid, parcel_uid)

  parcel_duplicates <- parcel_tabular %>%
    count(parcel_uid, name = "n_rows") %>%
    filter(n_rows > 1)

  canonical <- parcel_tabular %>%
    distinct(parcel_uid, .keep_all = TRUE)

  list(
    canonical = canonical,
    duplicates = parcel_duplicates,
    market_counties = market_counties
  )
}

attach_retail_classification <- function(parcels_canonical, land_use_mapping) {
  parcels_canonical %>%
    left_join(
      land_use_mapping %>%
        select(
          land_use_code,
          land_use_category = category,
          land_use_description = description,
          retail_flag,
          retail_subtype,
          review_note,
          mapping_version,
          mapping_method,
          classification_source_path
        ),
      by = "land_use_code"
    ) %>%
    mutate(
      retail_flag = dplyr::coalesce(retail_flag, FALSE),
      retail_subtype = dplyr::if_else(retail_flag & is.na(retail_subtype), "retail_uncategorized", retail_subtype),
      parcel_segment = dplyr::if_else(retail_flag, "Retail parcel", "Residential/other parcel"),
      build_source = "parcel.parcels_canonical + ref.land_use_mapping",
      run_timestamp = as.character(Sys.time())
    ) %>%
    arrange(market_key, county_geoid, parcel_uid)
}
