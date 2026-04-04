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

render_tract_features_sql <- function(sql_path, cbsa_code = TARGET_CBSA, target_year = TARGET_YEAR) {
  sql <- read_sql_template(sql_path)
  sql <- stringr::str_replace_all(sql, "27260", cbsa_code)
  sql <- stringr::str_replace_all(sql, "2024", as.character(target_year))
  sql
}

query_tract_features_for_market <- function(con, sql_path = resolve_sql_path("tract_features"), cbsa_code = TARGET_CBSA, target_year = TARGET_YEAR) {
  sql <- render_tract_features_sql(sql_path, cbsa_code = cbsa_code, target_year = target_year)
  DBI::dbGetQuery(con, sql)
}

read_optional_market_context_sf <- function(artifact_name, market_key = ACTIVE_MARKET_KEY) {
  path <- tryCatch(
    read_artifact_path("02_market_overview", artifact_name, key = market_key, subdir = "context_layers"),
    error = function(e) NULL
  )
  if (is.null(path) || !file.exists(path)) {
    return(NULL)
  }
  obj <- readRDS(path)
  if (!inherits(obj, "sf")) {
    return(NULL)
  }
  obj
}

build_foundation_products <- function(con, profile = get_market_profile()) {
  cbsa_features <- query_df_sql_file(con, resolve_sql_path("cbsa_features"))
  assert_required_columns(cbsa_features, REQUIRED_COLUMNS$cbsa_features, "cbsa_features")

  tract_features <- query_tract_features_for_market(con, cbsa_code = profile$cbsa_code, target_year = TARGET_YEAR)
  assert_required_columns(tract_features, REQUIRED_COLUMNS$tract_features, "tract_features")

  tract_wkb <- query_tract_geometry_wkb(con, profile = profile, cbsa_code = profile$cbsa_code)
  market_tract_geometry <- sf_from_wkb_df(tract_wkb, c("tract_geoid", "county_geoid", "state_fips", "cbsa_code"))

  county_wkb <- query_county_geometry_wkb(con, profile = profile, cbsa_code = profile$cbsa_code)
  market_county_geometry <- sf_from_wkb_df(county_wkb, c("county_geoid", "county_name", "state_fips", "cbsa_code"))

  cbsa_wkb <- query_cbsa_geometry_wkb(con, profile = profile, cbsa_code = profile$cbsa_code)
  market_cbsa_geometry <- sf_from_wkb_df(cbsa_wkb, c("cbsa_code", "cbsa_name"))

  context_cbsa_boundary <- read_optional_market_context_sf("section_02_context_cbsa_boundary_sf", profile$market_key)
  context_county_boundary <- read_optional_market_context_sf("section_02_context_county_sf", profile$market_key)
  context_places <- read_optional_market_context_sf("section_02_context_places_sf", profile$market_key)
  context_major_roads <- read_optional_market_context_sf("section_02_context_major_roads_sf", profile$market_key)
  context_water <- read_optional_market_context_sf("section_02_context_water_sf", profile$market_key)

  list(
    profile = profile,
    cbsa_features = prepend_market_metadata(cbsa_features, profile = profile, build_source = "sql/features/cbsa_features.sql"),
    tract_features = prepend_market_metadata(tract_features, profile = profile, build_source = "sql/features/tract_features.sql"),
    market_tract_geometry = prepend_market_metadata(
      sf_to_geometry_wkt_table(market_tract_geometry),
      profile = profile,
      build_source = "helpers::query_tract_geometry_wkb"
    ),
    market_county_geometry = prepend_market_metadata(
      sf_to_geometry_wkt_table(market_county_geometry),
      profile = profile,
      build_source = "helpers::query_county_geometry_wkb"
    ),
    market_cbsa_geometry = prepend_market_metadata(
      sf_to_geometry_wkt_table(market_cbsa_geometry),
      profile = profile,
      build_source = "helpers::query_cbsa_geometry_wkb"
    ),
    context_cbsa_boundary = if (is.null(context_cbsa_boundary)) NULL else prepend_market_metadata(
      sf_to_geometry_wkt_table(context_cbsa_boundary),
      profile = profile,
      build_source = "section_02_context_ingestion"
    ),
    context_county_boundary = if (is.null(context_county_boundary)) NULL else prepend_market_metadata(
      sf_to_geometry_wkt_table(context_county_boundary),
      profile = profile,
      build_source = "section_02_context_ingestion"
    ),
    context_places = if (is.null(context_places)) NULL else prepend_market_metadata(
      sf_to_geometry_wkt_table(context_places),
      profile = profile,
      build_source = "section_02_context_ingestion"
    ),
    context_major_roads = if (is.null(context_major_roads)) NULL else prepend_market_metadata(
      sf_to_geometry_wkt_table(context_major_roads),
      profile = profile,
      build_source = "section_02_context_ingestion"
    ),
    context_water = if (is.null(context_water)) NULL else prepend_market_metadata(
      sf_to_geometry_wkt_table(context_water),
      profile = profile,
      build_source = "section_02_context_ingestion"
    )
  )
}

build_foundation_qa <- function(products) {
  cbsa_feature_key_dupes <- nrow(products$cbsa_features) -
    dplyr::n_distinct(paste(products$cbsa_features$cbsa_code, products$cbsa_features$year, sep = "::"))
  tract_feature_key_dupes <- nrow(products$tract_features) -
    dplyr::n_distinct(paste(products$tract_features$market_key, products$tract_features$tract_geoid, products$tract_features$year, sep = "::"))

  validation_results <- dplyr::bind_rows(
    make_validation_row(
      "foundation_cbsa_features_required_columns",
      dataset = "foundation.cbsa_features",
      metric_value = validate_columns(products$cbsa_features, REQUIRED_COLUMNS$cbsa_features, "foundation.cbsa_features")$missing_count,
      pass = isTRUE(validate_columns(products$cbsa_features, REQUIRED_COLUMNS$cbsa_features, "foundation.cbsa_features")$pass),
      details = paste("Missing required columns:", validate_columns(products$cbsa_features, REQUIRED_COLUMNS$cbsa_features, "foundation.cbsa_features")$missing_count)
    ),
    make_validation_row(
      "foundation_tract_features_required_columns",
      dataset = "foundation.tract_features",
      metric_value = validate_columns(products$tract_features, REQUIRED_COLUMNS$tract_features, "foundation.tract_features")$missing_count,
      pass = isTRUE(validate_columns(products$tract_features, REQUIRED_COLUMNS$tract_features, "foundation.tract_features")$pass),
      details = paste("Missing required columns:", validate_columns(products$tract_features, REQUIRED_COLUMNS$tract_features, "foundation.tract_features")$missing_count)
    ),
    make_validation_row(
      "foundation_cbsa_features_unique_cbsa_year",
      dataset = "foundation.cbsa_features",
      metric_value = cbsa_feature_key_dupes,
      pass = cbsa_feature_key_dupes == 0,
      details = paste("Duplicate (cbsa_code, year) rows:", cbsa_feature_key_dupes)
    ),
    make_validation_row(
      "foundation_tract_features_unique_market_tract_year",
      dataset = "foundation.tract_features",
      metric_value = tract_feature_key_dupes,
      pass = tract_feature_key_dupes == 0,
      details = paste("Duplicate (market_key, tract_geoid, year) rows:", tract_feature_key_dupes)
    ),
    make_validation_row(
      "foundation_market_tract_geometry_positive_rows",
      dataset = "foundation.market_tract_geometry",
      metric_value = nrow(products$market_tract_geometry),
      pass = nrow(products$market_tract_geometry) > 0,
      details = paste("Market tract geometry rows:", nrow(products$market_tract_geometry))
    ),
    make_validation_row(
      "foundation_market_county_geometry_positive_rows",
      dataset = "foundation.market_county_geometry",
      metric_value = nrow(products$market_county_geometry),
      pass = nrow(products$market_county_geometry) > 0,
      details = paste("Market county geometry rows:", nrow(products$market_county_geometry))
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

  if (!is.null(products$context_cbsa_boundary)) {
    write_duckdb_table(con, "foundation", "context_cbsa_boundary", products$context_cbsa_boundary, overwrite = TRUE)
  }
  if (!is.null(products$context_county_boundary)) {
    write_duckdb_table(con, "foundation", "context_county_boundary", products$context_county_boundary, overwrite = TRUE)
  }
  if (!is.null(products$context_places)) {
    write_duckdb_table(con, "foundation", "context_places", products$context_places, overwrite = TRUE)
  }
  if (!is.null(products$context_major_roads)) {
    write_duckdb_table(con, "foundation", "context_major_roads", products$context_major_roads, overwrite = TRUE)
  }
  if (!is.null(products$context_water)) {
    write_duckdb_table(con, "foundation", "context_water", products$context_water, overwrite = TRUE)
  }

  write_duckdb_table(con, "qa", "foundation_validation_results", qa_outputs$validation_results, overwrite = TRUE)
  write_duckdb_table(con, "qa", "foundation_null_rates", qa_outputs$null_rates, overwrite = TRUE)

  invisible(
    list(
      cbsa_features = nrow(products$cbsa_features),
      tract_features = nrow(products$tract_features),
      market_tract_geometry = nrow(products$market_tract_geometry),
      market_county_geometry = nrow(products$market_county_geometry),
      market_cbsa_geometry = nrow(products$market_cbsa_geometry),
      validation_results = nrow(qa_outputs$validation_results),
      null_rates = nrow(qa_outputs$null_rates)
    )
  )
}
