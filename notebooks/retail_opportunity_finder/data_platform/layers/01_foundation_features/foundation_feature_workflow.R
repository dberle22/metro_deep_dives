source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

platform_helpers_path <- "notebooks/retail_opportunity_finder/data_platform/shared/platform_helpers.R"
if (!file.exists(platform_helpers_path)) {
  stop("Missing data platform helper file.", call. = FALSE)
}
source(platform_helpers_path)

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

read_sql_template <- function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

append_build_metadata <- function(df, build_source = NA_character_) {
  df %>%
    mutate(
      build_source = build_source,
      run_timestamp = as.character(Sys.time())
    )
}

build_foundation_geography_coverage <- function(con, products) {
  tract_universe <- DBI::dbGetQuery(con, "
    SELECT DISTINCT
      tract_geoid,
      state_fip AS state_fips,
      state_abbr
    FROM silver.xwalk_tract_county
  ")

  tract_geometry_source <- DBI::dbGetQuery(con, "
    SELECT DISTINCT
      tract_geoid,
      state_fips,
      state_abbr
    FROM metro_deep_dive.geo.tracts_supported_states
  ")

  feature_states <- products$tract_features %>%
    distinct(tract_geoid, cbsa_code) %>%
    left_join(tract_universe, by = "tract_geoid")

  market_geometry_states <- products$market_tract_geometry %>%
    distinct(tract_geoid) %>%
    left_join(tract_universe, by = "tract_geoid")

  universe_summary <- tract_universe %>%
    count(state_fips, state_abbr, name = "tract_universe_rows")

  feature_summary <- feature_states %>%
    group_by(state_fips, state_abbr) %>%
    summarise(
      tract_feature_rows = n(),
      cbsa_tract_feature_rows = sum(!is.na(cbsa_code) & nzchar(cbsa_code)),
      non_cbsa_tract_feature_rows = sum(is.na(cbsa_code) | !nzchar(cbsa_code)),
      .groups = "drop"
    )

  geometry_source_summary <- tract_geometry_source %>%
    count(state_fips, state_abbr, name = "tract_geometry_source_rows")

  market_geometry_summary <- market_geometry_states %>%
    count(state_fips, state_abbr, name = "market_tract_geometry_rows")

  universe_summary %>%
    full_join(feature_summary, by = c("state_fips", "state_abbr")) %>%
    full_join(geometry_source_summary, by = c("state_fips", "state_abbr")) %>%
    full_join(market_geometry_summary, by = c("state_fips", "state_abbr")) %>%
    mutate(
      tract_universe_rows = dplyr::coalesce(tract_universe_rows, 0L),
      tract_feature_rows = dplyr::coalesce(tract_feature_rows, 0L),
      cbsa_tract_feature_rows = dplyr::coalesce(cbsa_tract_feature_rows, 0L),
      non_cbsa_tract_feature_rows = dplyr::coalesce(non_cbsa_tract_feature_rows, 0L),
      tract_geometry_source_rows = dplyr::coalesce(tract_geometry_source_rows, 0L),
      market_tract_geometry_rows = dplyr::coalesce(market_tract_geometry_rows, 0L),
      tract_universe_minus_feature_rows = pmax(tract_universe_rows - tract_feature_rows, 0L),
      tract_universe_minus_geometry_source_rows = pmax(tract_universe_rows - tract_geometry_source_rows, 0L),
      geometry_source_minus_tract_universe_rows = pmax(tract_geometry_source_rows - tract_universe_rows, 0L)
    ) %>%
    arrange(state_fips, state_abbr) %>%
    mutate(
      build_source = "data_platform/layers/01_foundation_features",
      run_timestamp = as.character(Sys.time())
    )
}

FOUNDATION_FEATURE_LAYER_ROOT <- "notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features"
FOUNDATION_FEATURE_TABLE_ROOT <- file.path(FOUNDATION_FEATURE_LAYER_ROOT, "tables")

resolve_foundation_table_asset <- function(table_name, extension) {
  path <- file.path(FOUNDATION_FEATURE_TABLE_ROOT, paste0(table_name, ".", extension))
  if (!file.exists(path)) {
    stop(sprintf("Foundation layer table asset not found: %s", path), call. = FALSE)
  }
  path
}

query_cbsa_features_for_layer <- function(con, sql_path = resolve_foundation_table_asset("foundation.cbsa_features", "sql")) {
  query_df_sql_file(con, sql_path)
}

render_tract_features_sql <- function(sql_path, target_year = TARGET_YEAR) {
  sql <- read_sql_template(sql_path)
  sql <- stringr::str_replace_all(sql, "2024", as.character(target_year))
  sql
}

query_tract_features_for_layer <- function(con, sql_path = resolve_foundation_table_asset("foundation.tract_features", "sql"), target_year = TARGET_YEAR) {
  sql <- render_tract_features_sql(sql_path, target_year = target_year)
  DBI::dbGetQuery(con, sql)
}

query_tract_features_for_market <- function(con, sql_path = resolve_foundation_table_asset("foundation.tract_features", "sql"), cbsa_code = TARGET_CBSA, target_year = TARGET_YEAR) {
  sql <- render_tract_features_sql(sql_path, target_year = target_year)
  sql <- paste0(
    "SELECT * FROM (", sql, ") AS tract_features WHERE cbsa_code = ",
    DBI::dbQuoteString(con, cbsa_code)
  )
  DBI::dbGetQuery(con, sql)
}

query_market_tract_geometry_for_layer <- function(con, sql_path = resolve_foundation_table_asset("foundation.market_tract_geometry", "sql")) {
  query_df_sql_file(con, sql_path)
}

query_market_county_geometry_for_layer <- function(con, sql_path = resolve_foundation_table_asset("foundation.market_county_geometry", "sql")) {
  query_df_sql_file(con, sql_path)
}

query_market_cbsa_geometry_for_layer <- function(con, sql_path = resolve_foundation_table_asset("foundation.market_cbsa_geometry", "sql")) {
  query_df_sql_file(con, sql_path)
}

build_foundation_products <- function(con, profile = get_market_profile()) {
  cbsa_features <- query_cbsa_features_for_layer(con)
  assert_required_columns(cbsa_features, REQUIRED_COLUMNS$cbsa_features, "cbsa_features")

  tract_features <- query_tract_features_for_layer(con, target_year = TARGET_YEAR)
  assert_required_columns(tract_features, REQUIRED_COLUMNS$tract_features, "tract_features")

  market_tract_geometry <- query_market_tract_geometry_for_layer(con)
  market_county_geometry <- query_market_county_geometry_for_layer(con)
  market_cbsa_geometry <- query_market_cbsa_geometry_for_layer(con)

  list(
    profile = profile,
    cbsa_features = append_build_metadata(
      cbsa_features,
      build_source = "data_platform/layers/01_foundation_features/tables/foundation.cbsa_features.sql"
    ),
    tract_features = append_build_metadata(
      tract_features,
      build_source = "data_platform/layers/01_foundation_features/tables/foundation.tract_features.sql"
    ),
    market_tract_geometry = append_build_metadata(
      market_tract_geometry,
      build_source = "data_platform/layers/01_foundation_features/tables/foundation.market_tract_geometry.sql"
    ),
    market_county_geometry = append_build_metadata(
      market_county_geometry,
      build_source = "data_platform/layers/01_foundation_features/tables/foundation.market_county_geometry.sql"
    ),
    market_cbsa_geometry = append_build_metadata(
      market_cbsa_geometry,
      build_source = "data_platform/layers/01_foundation_features/tables/foundation.market_cbsa_geometry.sql"
    )
  )
}

build_foundation_qa <- function(con, products) {
  cbsa_column_check <- validate_columns(products$cbsa_features, REQUIRED_COLUMNS$cbsa_features, "foundation.cbsa_features")
  tract_column_check <- validate_columns(products$tract_features, REQUIRED_COLUMNS$tract_features, "foundation.tract_features")
  cbsa_feature_key_dupes <- nrow(products$cbsa_features) -
    dplyr::n_distinct(paste(products$cbsa_features$cbsa_code, products$cbsa_features$year, sep = "::"))
  tract_feature_key_dupes <- nrow(products$tract_features) -
    dplyr::n_distinct(paste(products$tract_features$cbsa_code, products$tract_features$tract_geoid, products$tract_features$year, sep = "::"))
  tract_geometry_key_dupes <- nrow(products$market_tract_geometry) -
    dplyr::n_distinct(paste(products$market_tract_geometry$cbsa_code, products$market_tract_geometry$tract_geoid, sep = "::"))
  county_geometry_key_dupes <- nrow(products$market_county_geometry) -
    dplyr::n_distinct(paste(products$market_county_geometry$cbsa_code, products$market_county_geometry$county_geoid, sep = "::"))
  cbsa_geometry_key_dupes <- nrow(products$market_cbsa_geometry) -
    dplyr::n_distinct(products$market_cbsa_geometry$cbsa_code)
  tract_null_cbsa_count <- sum(is.na(products$tract_features$cbsa_code) | products$tract_features$cbsa_code == "")
  tract_geometry_gap <- dplyr::n_distinct(products$tract_features$tract_geoid) -
    dplyr::n_distinct(products$market_tract_geometry$tract_geoid)
  cbsa_feature_scope <- dplyr::n_distinct(products$cbsa_features$cbsa_code, na.rm = TRUE)
  tract_feature_scope <- dplyr::n_distinct(products$tract_features$cbsa_code, na.rm = TRUE)
  tract_geometry_scope <- dplyr::n_distinct(products$market_tract_geometry$cbsa_code, na.rm = TRUE)
  county_geometry_scope <- dplyr::n_distinct(products$market_county_geometry$cbsa_code, na.rm = TRUE)
  cbsa_geometry_scope <- dplyr::n_distinct(products$market_cbsa_geometry$cbsa_code, na.rm = TRUE)
  geography_coverage <- build_foundation_geography_coverage(con, products)
  tract_universe_state_count <- dplyr::n_distinct(geography_coverage$state_abbr[geography_coverage$tract_universe_rows > 0], na.rm = TRUE)
  tract_feature_gap_total <- sum(geography_coverage$tract_universe_minus_feature_rows, na.rm = TRUE)
  geometry_source_gap_total <- sum(geography_coverage$tract_universe_minus_geometry_source_rows, na.rm = TRUE)
  geometry_source_extra_total <- sum(geography_coverage$geometry_source_minus_tract_universe_rows, na.rm = TRUE)

  validation_results <- dplyr::bind_rows(
    make_validation_row(
      "foundation_cbsa_features_required_columns",
      dataset = "foundation.cbsa_features",
      metric_value = cbsa_column_check$missing_count,
      pass = isTRUE(cbsa_column_check$pass),
      details = paste("Missing required columns:", cbsa_column_check$missing_count)
    ),
    make_validation_row(
      "foundation_tract_features_required_columns",
      dataset = "foundation.tract_features",
      metric_value = tract_column_check$missing_count,
      pass = isTRUE(tract_column_check$pass),
      details = paste("Missing required columns:", tract_column_check$missing_count)
    ),
    make_validation_row(
      "foundation_cbsa_features_unique_cbsa_year",
      dataset = "foundation.cbsa_features",
      metric_value = cbsa_feature_key_dupes,
      pass = cbsa_feature_key_dupes == 0,
      details = paste("Duplicate (cbsa_code, year) rows:", cbsa_feature_key_dupes)
    ),
    make_validation_row(
      "foundation_tract_features_unique_cbsa_tract_year",
      dataset = "foundation.tract_features",
      metric_value = tract_feature_key_dupes,
      pass = tract_feature_key_dupes == 0,
      details = paste("Duplicate (cbsa_code, tract_geoid, year) rows:", tract_feature_key_dupes)
    ),
    make_validation_row(
      "foundation_tract_features_null_cbsa_code",
      severity = "warn",
      dataset = "foundation.tract_features",
      metric_value = tract_null_cbsa_count,
      pass = tract_null_cbsa_count == 0,
      details = paste("Rows with null or blank cbsa_code:", tract_null_cbsa_count)
    ),
    make_validation_row(
      "foundation_cbsa_features_national_cbsa_coverage",
      severity = "warn",
      dataset = "foundation.cbsa_features",
      metric_value = cbsa_feature_scope,
      pass = cbsa_feature_scope > 1,
      details = paste("Distinct non-null cbsa_code values:", cbsa_feature_scope)
    ),
    make_validation_row(
      "foundation_tract_features_national_cbsa_coverage",
      severity = "warn",
      dataset = "foundation.tract_features",
      metric_value = tract_feature_scope,
      pass = tract_feature_scope > 1,
      details = paste("Distinct non-null cbsa_code values:", tract_feature_scope)
    ),
    make_validation_row(
      "foundation_tract_universe_national_state_coverage",
      severity = "warn",
      dataset = "silver.xwalk_tract_county",
      metric_value = tract_universe_state_count,
      pass = tract_universe_state_count >= 51,
      details = paste("Distinct tract universe states present:", tract_universe_state_count)
    ),
    make_validation_row(
      "foundation_tract_features_gap_vs_tract_universe",
      severity = "warn",
      dataset = "foundation.tract_features",
      metric_value = tract_feature_gap_total,
      pass = tract_feature_gap_total == 0,
      details = paste("Total tract universe minus feature rows:", tract_feature_gap_total)
    ),
    make_validation_row(
      "foundation_tract_geometry_source_gap_vs_tract_universe",
      severity = "warn",
      dataset = "metro_deep_dive.geo.tracts_supported_states",
      metric_value = geometry_source_gap_total,
      pass = geometry_source_gap_total == 0,
      details = paste("Total tract universe minus geometry-source rows:", geometry_source_gap_total)
    ),
    make_validation_row(
      "foundation_tract_geometry_source_extra_vs_tract_universe",
      severity = "warn",
      dataset = "metro_deep_dive.geo.tracts_supported_states",
      metric_value = geometry_source_extra_total,
      pass = geometry_source_extra_total == 0,
      details = paste("Total geometry-source rows beyond tract universe:", geometry_source_extra_total)
    ),
    make_validation_row(
      "foundation_market_tract_geometry_positive_rows",
      dataset = "foundation.market_tract_geometry",
      metric_value = nrow(products$market_tract_geometry),
      pass = nrow(products$market_tract_geometry) > 0,
      details = paste("Market tract geometry rows:", nrow(products$market_tract_geometry))
    ),
    make_validation_row(
      "foundation_market_tract_geometry_unique_cbsa_tract",
      dataset = "foundation.market_tract_geometry",
      metric_value = tract_geometry_key_dupes,
      pass = tract_geometry_key_dupes == 0,
      details = paste("Duplicate (cbsa_code, tract_geoid) rows:", tract_geometry_key_dupes)
    ),
    make_validation_row(
      "foundation_market_tract_geometry_national_cbsa_coverage",
      severity = "warn",
      dataset = "foundation.market_tract_geometry",
      metric_value = tract_geometry_scope,
      pass = tract_geometry_scope > 1,
      details = paste("Distinct non-null cbsa_code values:", tract_geometry_scope)
    ),
    make_validation_row(
      "foundation_market_tract_geometry_vs_tract_features_coverage_gap",
      severity = "warn",
      dataset = "foundation.market_tract_geometry",
      metric_value = tract_geometry_gap,
      pass = tract_geometry_gap == 0,
      details = paste("Distinct tract_geoid gap versus foundation.tract_features:", tract_geometry_gap)
    ),
    make_validation_row(
      "foundation_market_county_geometry_positive_rows",
      dataset = "foundation.market_county_geometry",
      metric_value = nrow(products$market_county_geometry),
      pass = nrow(products$market_county_geometry) > 0,
      details = paste("Market county geometry rows:", nrow(products$market_county_geometry))
    ),
    make_validation_row(
      "foundation_market_county_geometry_unique_cbsa_county",
      dataset = "foundation.market_county_geometry",
      metric_value = county_geometry_key_dupes,
      pass = county_geometry_key_dupes == 0,
      details = paste("Duplicate (cbsa_code, county_geoid) rows:", county_geometry_key_dupes)
    ),
    make_validation_row(
      "foundation_market_county_geometry_national_cbsa_coverage",
      severity = "warn",
      dataset = "foundation.market_county_geometry",
      metric_value = county_geometry_scope,
      pass = county_geometry_scope > 1,
      details = paste("Distinct non-null cbsa_code values:", county_geometry_scope)
    ),
    make_validation_row(
      "foundation_market_cbsa_geometry_positive_rows",
      dataset = "foundation.market_cbsa_geometry",
      metric_value = nrow(products$market_cbsa_geometry),
      pass = nrow(products$market_cbsa_geometry) > 0,
      details = paste("Market cbsa geometry rows:", nrow(products$market_cbsa_geometry))
    ),
    make_validation_row(
      "foundation_market_cbsa_geometry_unique_cbsa",
      dataset = "foundation.market_cbsa_geometry",
      metric_value = cbsa_geometry_key_dupes,
      pass = cbsa_geometry_key_dupes == 0,
      details = paste("Duplicate cbsa_code rows:", cbsa_geometry_key_dupes)
    ),
    make_validation_row(
      "foundation_market_cbsa_geometry_national_cbsa_coverage",
      severity = "warn",
      dataset = "foundation.market_cbsa_geometry",
      metric_value = cbsa_geometry_scope,
      pass = cbsa_geometry_scope > 1,
      details = paste("Distinct non-null cbsa_code values:", cbsa_geometry_scope)
    )
  ) %>%
    mutate(
      build_source = "data_platform/layers/01_foundation_features",
      run_timestamp = as.character(Sys.time())
    )

  null_rates <- dplyr::bind_rows(
    null_rate_summary(products$cbsa_features, c("pop_total", "pop_growth_5yr", "median_gross_rent", "median_home_value", "mean_travel_time"), "foundation.cbsa_features"),
    null_rate_summary(products$tract_features, c("pop_total", "pop_growth_3yr", "median_gross_rent", "median_home_value", "mean_travel_time", "median_hh_income"), "foundation.tract_features")
  ) %>%
    mutate(
      build_source = "data_platform/layers/01_foundation_features",
      run_timestamp = as.character(Sys.time())
    )

  validation_results

  list(
    validation_results = validation_results,
    geography_coverage = geography_coverage,
    null_rates = null_rates
  )
}

publish_foundation_products <- function(con, products, qa_outputs) {
  ensure_rof_duckdb_schemas(con)

  write_duckdb_table(con, "foundation", "cbsa_features", products$cbsa_features, overwrite = TRUE)
  write_duckdb_table(con, "foundation", "tract_features", products$tract_features, overwrite = TRUE)
  write_duckdb_table(con, "foundation", "market_tract_geometry", products$market_tract_geometry, overwrite = TRUE)
  write_duckdb_table(con, "foundation", "market_county_geometry", products$market_county_geometry, overwrite = TRUE)
  write_duckdb_table(con, "foundation", "market_cbsa_geometry", products$market_cbsa_geometry, overwrite = TRUE)

  stale_context_tables <- c(
    "context_cbsa_boundary",
    "context_county_boundary",
    "context_places",
    "context_major_roads",
    "context_water"
  )
  invisible(lapply(stale_context_tables, function(table_name) {
    if (duckdb_table_exists(con, "foundation", table_name)) {
      DBI::dbRemoveTable(con, rof_schema_table("foundation", table_name))
    }
  }))

  write_duckdb_table(con, "qa", "foundation_validation_results", qa_outputs$validation_results, overwrite = TRUE)
  write_duckdb_table(con, "qa", "foundation_geography_coverage", qa_outputs$geography_coverage, overwrite = TRUE)
  write_duckdb_table(con, "qa", "foundation_null_rates", qa_outputs$null_rates, overwrite = TRUE)

  invisible(
    list(
      cbsa_features = nrow(products$cbsa_features),
      tract_features = nrow(products$tract_features),
      market_tract_geometry = nrow(products$market_tract_geometry),
      market_county_geometry = nrow(products$market_county_geometry),
      market_cbsa_geometry = nrow(products$market_cbsa_geometry),
      validation_results = nrow(qa_outputs$validation_results),
      geography_coverage = nrow(qa_outputs$geography_coverage),
      null_rates = nrow(qa_outputs$null_rates)
    )
  )
}
