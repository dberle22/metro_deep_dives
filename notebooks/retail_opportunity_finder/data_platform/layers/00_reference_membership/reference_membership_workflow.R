source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

platform_helpers_path <- "notebooks/retail_opportunity_finder/data_platform/shared/platform_helpers.R"
if (!file.exists(platform_helpers_path)) {
  stop("Missing data platform helper file.", call. = FALSE)
}
source(platform_helpers_path)

LAND_USE_MAPPING_SOURCE_PATH <- "notebooks/retail_opportunity_finder/land_use_code_mapping.csv"
LAND_USE_MAPPING_CANDIDATES_PATH <- "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_retail_land_use_mapping_candidates_v0_1.csv"

build_ref_market_profiles <- function() {
  rows <- lapply(MARKET_PROFILES, function(profile) {
    tibble::tibble(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      state_scope = paste(profile$state_scope, collapse = ","),
      benchmark_region_type = profile$benchmark_region_type,
      benchmark_region_value = profile$benchmark_region_value,
      benchmark_region_label = profile$benchmark_region_label,
      peer_count = length(profile$peers),
      cbsa_name = profile$labels$cbsa_name,
      cbsa_name_full = profile$labels$cbsa_name_full,
      market_name = profile$labels$market_name,
      peer_group = profile$labels$peer_group,
      target_flag = profile$labels$target_flag,
      us_label = profile$labels$us_label,
      build_source = "sections/_shared/market_profiles.R",
      run_timestamp = as.character(Sys.time())
    )
  })

  dplyr::bind_rows(rows) %>%
    arrange(market_key)
}

build_ref_market_cbsa_membership <- function() {
  rows <- lapply(MARKET_PROFILES, function(profile) {
    target_row <- tibble::tibble(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      membership_type = "target",
      membership_order = 0L
    )

    peer_rows <- tibble::tibble(
      market_key = profile$market_key,
      cbsa_code = as.character(profile$peers),
      membership_type = "peer",
      membership_order = seq_along(profile$peers)
    )

    dplyr::bind_rows(target_row, peer_rows)
  })

  dplyr::bind_rows(rows) %>%
    distinct(market_key, cbsa_code, membership_type, .keep_all = TRUE) %>%
    left_join(
      build_ref_market_profiles() %>%
        select(
          market_key,
          target_cbsa_code = cbsa_code,
          benchmark_region_type,
          benchmark_region_value,
          benchmark_region_label
        ),
      by = "market_key"
    ) %>%
    mutate(
      build_source = "sections/_shared/market_profiles.R",
      run_timestamp = as.character(Sys.time())
    ) %>%
    arrange(market_key, membership_type, membership_order, cbsa_code)
}

build_ref_market_county_membership <- function(con) {
  market_profiles <- build_ref_market_profiles()
  cbsa_county <- DBI::dbGetQuery(con, "
    SELECT
      cbsa_code,
      cbsa_name,
      county_geoid,
      county_name,
      state_fips,
      county_fips,
      state_name,
      vintage,
      source
    FROM silver.xwalk_cbsa_county
  ")

  market_profiles %>%
    select(market_key, cbsa_code, state_scope) %>%
    inner_join(cbsa_county, by = "cbsa_code") %>%
    mutate(
      state_abbr = state.abb[match(state_name, state.name)],
      build_source = "silver.xwalk_cbsa_county",
      run_timestamp = as.character(Sys.time())
    ) %>%
    arrange(market_key, county_geoid)
}

build_ref_county_dim <- function(con) {
  DBI::dbGetQuery(con, "
    SELECT
      county_geoid,
      state_fips,
      county_fips,
      county_name,
      STUSPS AS state_abbr,
      STATE_NAME AS state_name,
      land_area_sqmi,
      water_area_sqmi,
      'metro_deep_dive.geo.counties' AS build_source,
      CAST(NOW() AS VARCHAR) AS run_timestamp
    FROM metro_deep_dive.geo.counties
  ") %>%
    arrange(county_geoid)
}

build_ref_tract_dim <- function(con) {
  tract_membership <- DBI::dbGetQuery(con, "
    SELECT
      tract_geoid,
      tract_name,
      tract_name_long,
      printf('%02d%03d', CAST(state_fip AS INTEGER), CAST(county_fip AS INTEGER)) AS county_geoid,
      state_fip AS state_fips,
      county_fip AS county_fips,
      state_abbr,
      county_name,
      state_name,
      vintage,
      source
    FROM silver.xwalk_tract_county
  ")

  tract_membership %>%
    mutate(
      build_source = "silver.xwalk_tract_county",
      run_timestamp = as.character(Sys.time())
    ) %>%
    arrange(tract_geoid)
}

build_ref_land_use_mapping <- function(path = LAND_USE_MAPPING_SOURCE_PATH) {
  if (!file.exists(path)) {
    stop("Land use mapping source CSV not found.", call. = FALSE)
  }

  source_mapping <- readr::read_csv(path, show_col_types = FALSE) %>%
    mutate(
      land_use_code = stringr::str_pad(as.character(land_use_code), width = 3, side = "left", pad = "0"),
      source_system = "Florida Department of Revenue land use code documentation",
      source_path = path
    ) %>%
    arrange(land_use_code)

  reviewed_mapping <- if (file.exists(LAND_USE_MAPPING_CANDIDATES_PATH)) {
    readr::read_csv(LAND_USE_MAPPING_CANDIDATES_PATH, show_col_types = FALSE) %>%
      transmute(
        land_use_code = stringr::str_pad(as.character(use_code), width = 3, side = "left", pad = "0"),
        retail_flag = as.logical(retail_flag),
        retail_subtype = as.character(retail_subtype),
        review_note = as.character(review_note),
        reviewed_n_parcels = as.numeric(n_parcels),
        classification_source_path = LAND_USE_MAPPING_CANDIDATES_PATH
      ) %>%
      distinct(land_use_code, .keep_all = TRUE)
  } else {
    tibble::tibble(
      land_use_code = character(),
      retail_flag = logical(),
      retail_subtype = character(),
      review_note = character(),
      reviewed_n_parcels = numeric(),
      classification_source_path = character()
    )
  }

  source_mapping %>%
    left_join(reviewed_mapping, by = "land_use_code") %>%
    mutate(
      retail_flag = dplyr::coalesce(retail_flag, FALSE),
      retail_subtype = dplyr::if_else(retail_flag & is.na(retail_subtype), "retail_uncategorized", retail_subtype),
      mapping_version = "v2_source_plus_review_overlay",
      mapping_method = dplyr::if_else(
        !is.na(classification_source_path),
        "review_overlay_from_section_05_candidates",
        "source_only_default_non_retail"
      ),
      build_source = "notebooks/retail_opportunity_finder/land_use_code_mapping.csv + section_05_retail_land_use_mapping_candidates_v0_1.csv",
      run_timestamp = as.character(Sys.time())
    ) %>%
    arrange(land_use_code)
}

check_regex_match <- function(x, pattern) {
  !is.na(x) & stringr::str_detect(x, pattern)
}

make_validation_row <- function(check_name, severity = "error", dataset = NA_character_, metric_value = NA_real_, pass = FALSE, details = NA_character_) {
  tibble::tibble(
    check_name = check_name,
    severity = severity,
    dataset = dataset,
    metric_value = metric_value,
    pass = pass,
    details = details
  )
}

build_unmapped_land_use_codes <- function(ref_products, candidates_path = LAND_USE_MAPPING_CANDIDATES_PATH) {
  if (!file.exists(candidates_path)) {
    return(tibble::tibble(
      land_use_code = character(),
      candidate_description = character(),
      candidate_type = character(),
      n_parcels = numeric(),
      candidate_path = character()
    ))
  }

  candidates <- readr::read_csv(candidates_path, show_col_types = FALSE) %>%
    transmute(
      land_use_code = stringr::str_pad(as.character(use_code), width = 3, side = "left", pad = "0"),
      candidate_description = as.character(definition.x),
      candidate_type = as.character(type.x),
      n_parcels = as.numeric(n_parcels),
      candidate_path = candidates_path
    )

  candidates %>%
    anti_join(ref_products$land_use_mapping %>% select(land_use_code), by = "land_use_code") %>%
    arrange(land_use_code)
}

build_ref_geography_coverage <- function(ref_products) {
  ref_products$tract_dim %>%
    mutate(
      state_fips = as.character(state_fips),
      state_abbr = as.character(state_abbr)
    ) %>%
    group_by(state_fips, state_abbr) %>%
    summarise(
      tract_dim_rows = n(),
      county_rows = n_distinct(county_geoid),
      .groups = "drop"
    ) %>%
    arrange(state_fips, state_abbr) %>%
    mutate(
      build_source = "data_platform/layers/00_reference_membership",
      run_timestamp = as.character(Sys.time())
    )
}

build_reference_qa_checks <- function(ref_products) {
  market_profiles_unique <- validate_unique_key(ref_products$market_profiles, "market_key", "ref.market_profiles")
  county_dim_unique <- validate_unique_key(ref_products$county_dim, "county_geoid", "ref.county_dim")
  tract_dim_unique <- validate_unique_key(ref_products$tract_dim, "tract_geoid", "ref.tract_dim")
  land_use_mapping_unique <- validate_unique_key(ref_products$land_use_mapping, "land_use_code", "ref.land_use_mapping")

  market_county_duplicates <- nrow(ref_products$market_county_membership) -
    dplyr::n_distinct(paste(ref_products$market_county_membership$market_key, ref_products$market_county_membership$county_geoid, sep = "::"))

  market_cbsa_duplicates <- nrow(ref_products$market_cbsa_membership) -
    dplyr::n_distinct(paste(
      ref_products$market_cbsa_membership$market_key,
      ref_products$market_cbsa_membership$cbsa_code,
      ref_products$market_cbsa_membership$membership_type,
      sep = "::"
    ))

  invalid_state_fips_county <- sum(!check_regex_match(ref_products$market_county_membership$state_fips, "^[0-9]{2}$"))
  invalid_county_fips_county <- sum(!check_regex_match(ref_products$market_county_membership$county_fips, "^[0-9]{3}$"))
  invalid_county_geoid_membership <- sum(!check_regex_match(ref_products$market_county_membership$county_geoid, "^[0-9]{5}$"))
  invalid_county_geoid_dim <- sum(!check_regex_match(ref_products$county_dim$county_geoid, "^[0-9]{5}$"))
  invalid_tract_geoid_dim <- sum(!check_regex_match(ref_products$tract_dim$tract_geoid, "^[0-9]{11}$"))
  missing_market_keys <- sum(is.na(ref_products$market_county_membership$market_key) | !nzchar(ref_products$market_county_membership$market_key))
  missing_state_abbr <- sum(is.na(ref_products$market_county_membership$state_abbr) | !nzchar(ref_products$market_county_membership$state_abbr))
  tract_dim_state_count <- dplyr::n_distinct(ref_products$tract_dim$state_abbr, na.rm = TRUE)

  unmapped_land_use_codes <- build_unmapped_land_use_codes(ref_products)
  geography_coverage <- build_ref_geography_coverage(ref_products)

  validation_results <- dplyr::bind_rows(
    make_validation_row(
      "market_profiles_unique_market_key",
      dataset = "ref.market_profiles",
      metric_value = market_profiles_unique$duplicates,
      pass = isTRUE(market_profiles_unique$pass),
      details = paste("Duplicate market_key rows:", market_profiles_unique$duplicates)
    ),
    make_validation_row(
      "market_county_membership_unique_market_county",
      dataset = "ref.market_county_membership",
      metric_value = market_county_duplicates,
      pass = identical(market_county_duplicates, 0L),
      details = paste("Duplicate (market_key, county_geoid) rows:", market_county_duplicates)
    ),
    make_validation_row(
      "market_cbsa_membership_unique_market_cbsa_type",
      dataset = "ref.market_cbsa_membership",
      metric_value = market_cbsa_duplicates,
      pass = identical(market_cbsa_duplicates, 0L),
      details = paste("Duplicate (market_key, cbsa_code, membership_type) rows:", market_cbsa_duplicates)
    ),
    make_validation_row(
      "market_county_membership_valid_state_fips",
      dataset = "ref.market_county_membership",
      metric_value = invalid_state_fips_county,
      pass = identical(invalid_state_fips_county, 0L),
      details = paste("Invalid state_fips rows:", invalid_state_fips_county)
    ),
    make_validation_row(
      "market_county_membership_valid_county_fips",
      dataset = "ref.market_county_membership",
      metric_value = invalid_county_fips_county,
      pass = identical(invalid_county_fips_county, 0L),
      details = paste("Invalid county_fips rows:", invalid_county_fips_county)
    ),
    make_validation_row(
      "market_county_membership_valid_county_geoid",
      dataset = "ref.market_county_membership",
      metric_value = invalid_county_geoid_membership,
      pass = identical(invalid_county_geoid_membership, 0L),
      details = paste("Invalid county_geoid rows:", invalid_county_geoid_membership)
    ),
    make_validation_row(
      "county_dim_valid_county_geoid",
      dataset = "ref.county_dim",
      metric_value = invalid_county_geoid_dim,
      pass = identical(invalid_county_geoid_dim, 0L),
      details = paste("Invalid county_dim county_geoid rows:", invalid_county_geoid_dim)
    ),
    make_validation_row(
      "tract_dim_valid_tract_geoid",
      dataset = "ref.tract_dim",
      metric_value = invalid_tract_geoid_dim,
      pass = identical(invalid_tract_geoid_dim, 0L),
      details = paste("Invalid tract_geoid rows:", invalid_tract_geoid_dim)
    ),
    make_validation_row(
      "tract_dim_national_state_coverage",
      severity = "warn",
      dataset = "ref.tract_dim",
      metric_value = tract_dim_state_count,
      pass = tract_dim_state_count >= 51,
      details = paste("Distinct tract_dim states present:", tract_dim_state_count)
    ),
    make_validation_row(
      "market_county_membership_missing_market_key",
      dataset = "ref.market_county_membership",
      metric_value = missing_market_keys,
      pass = identical(missing_market_keys, 0L),
      details = paste("Missing market_key rows:", missing_market_keys)
    ),
    make_validation_row(
      "market_county_membership_missing_state_abbr",
      dataset = "ref.market_county_membership",
      metric_value = missing_state_abbr,
      pass = identical(missing_state_abbr, 0L),
      details = paste("Missing state_abbr rows:", missing_state_abbr)
    ),
    make_validation_row(
      "land_use_mapping_unique_land_use_code",
      dataset = "ref.land_use_mapping",
      metric_value = land_use_mapping_unique$duplicates,
      pass = isTRUE(land_use_mapping_unique$pass),
      details = paste("Duplicate land_use_code rows:", land_use_mapping_unique$duplicates)
    ),
    make_validation_row(
      "land_use_mapping_unmapped_candidate_codes",
      dataset = "ref.land_use_mapping",
      metric_value = nrow(unmapped_land_use_codes),
      pass = nrow(unmapped_land_use_codes) == 0,
      details = paste("Candidate codes not covered by ref.land_use_mapping:", nrow(unmapped_land_use_codes))
    )
  ) %>%
    mutate(
      build_source = "data_platform/layers/00_reference_membership",
      run_timestamp = as.character(Sys.time())
    )

  list(
    validation_results = validation_results,
    geography_coverage = geography_coverage,
    unmapped_land_use_codes = unmapped_land_use_codes,
    legacy_checks = list(
      market_profiles_unique = market_profiles_unique,
      county_dim_unique = county_dim_unique,
      tract_dim_unique = tract_dim_unique,
      land_use_mapping_unique = land_use_mapping_unique
    )
  )
}

build_reference_membership_products <- function(con) {
  products <- list(
    market_profiles = build_ref_market_profiles(),
    market_cbsa_membership = build_ref_market_cbsa_membership(),
    market_county_membership = build_ref_market_county_membership(con),
    county_dim = build_ref_county_dim(con),
    tract_dim = build_ref_tract_dim(con),
    land_use_mapping = build_ref_land_use_mapping()
  )

  qa_outputs <- build_reference_qa_checks(products)
  products$qa_checks <- qa_outputs$legacy_checks
  products$qa_validation_results <- qa_outputs$validation_results
  products$qa_geography_coverage <- qa_outputs$geography_coverage
  products$qa_unmapped_land_use_codes <- qa_outputs$unmapped_land_use_codes
  products
}

publish_reference_membership_products <- function(con, products) {
  ensure_rof_duckdb_schemas(con)

  write_duckdb_table(con, "ref", "market_profiles", products$market_profiles, overwrite = TRUE)
  write_duckdb_table(con, "ref", "market_cbsa_membership", products$market_cbsa_membership, overwrite = TRUE)
  write_duckdb_table(con, "ref", "market_county_membership", products$market_county_membership, overwrite = TRUE)
  write_duckdb_table(con, "ref", "county_dim", products$county_dim, overwrite = TRUE)
  write_duckdb_table(con, "ref", "tract_dim", products$tract_dim, overwrite = TRUE)
  write_duckdb_table(con, "ref", "land_use_mapping", products$land_use_mapping, overwrite = TRUE)
  write_duckdb_table(con, "qa", "ref_validation_results", products$qa_validation_results, overwrite = TRUE)
  write_duckdb_table(con, "qa", "ref_geography_coverage", products$qa_geography_coverage, overwrite = TRUE)
  write_duckdb_table(con, "qa", "ref_unmapped_land_use_codes", products$qa_unmapped_land_use_codes, overwrite = TRUE)

  invisible(
    list(
      market_profiles = nrow(products$market_profiles),
      market_cbsa_membership = nrow(products$market_cbsa_membership),
      market_county_membership = nrow(products$market_county_membership),
      county_dim = nrow(products$county_dim),
      tract_dim = nrow(products$tract_dim),
      land_use_mapping = nrow(products$land_use_mapping),
      qa_validation_results = nrow(products$qa_validation_results),
      qa_geography_coverage = nrow(products$qa_geography_coverage),
      qa_unmapped_land_use_codes = nrow(products$qa_unmapped_land_use_codes)
    )
  )
}
