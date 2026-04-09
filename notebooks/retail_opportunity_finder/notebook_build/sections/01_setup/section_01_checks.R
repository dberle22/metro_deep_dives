# Notebook-build Section 01 checks
# Purpose: Validate setup artifacts and required foundation tables using read-only access.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()
source("notebooks/retail_opportunity_finder/notebook_build/_shared/read_only_build_helpers.R")

message("Running notebook_build section 01 checks: 01_setup")

market_profile <- get_market_profile()
market_context <- get_market_context()
market_profile_check <- validate_market_profile(market_profile)
section_output_dir <- resolve_market_output_dir("01_setup")

con <- connect_project_duckdb(read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

assert_duckdb_tables(
  con,
  c(
    "foundation.cbsa_features",
    "foundation.tract_features",
    "foundation.market_cbsa_geometry",
    "foundation.market_county_geometry",
    "foundation.market_tract_geometry"
  )
)

cbsa_features <- read_market_table(
  con,
  "foundation.cbsa_features",
  profile = market_profile,
  apply_default_filter = FALSE
) %>%
  drop_platform_metadata()

tract_features <- read_market_table(
  con,
  "foundation.tract_features",
  profile = market_profile,
  order_sql = "tract_geoid"
) %>%
  drop_platform_metadata()

cbsa_sf <- read_market_sf_table(
  con,
  "foundation.market_cbsa_geometry",
  profile = market_profile
) %>%
  drop_platform_metadata()

county_sf <- read_market_sf_table(
  con,
  "foundation.market_county_geometry",
  profile = market_profile,
  order_sql = "county_geoid"
) %>%
  drop_platform_metadata()

tract_sf <- read_market_sf_table(
  con,
  "foundation.market_tract_geometry",
  profile = market_profile,
  order_sql = "tract_geoid"
) %>%
  drop_platform_metadata()

column_checks <- list(
  tract_features = validate_columns(
    tract_features,
    c("tract_geoid", "cbsa_code", "county_geoid", "land_area_sqmi", "pop_density", "median_gross_rent", "median_home_value"),
    "foundation.tract_features"
  ),
  cbsa_features = validate_columns(
    cbsa_features,
    c("cbsa_code", "cbsa_name", "year", "pop_total", "pop_growth_5yr", "median_gross_rent", "median_home_value"),
    "foundation.cbsa_features"
  ),
  tract_geom = validate_columns(
    sf::st_drop_geometry(tract_sf),
    c("tract_geoid", "county_geoid", "state_fips", "cbsa_code"),
    "foundation.market_tract_geometry"
  ),
  county_geom = validate_columns(
    sf::st_drop_geometry(county_sf),
    c("county_geoid", "county_name", "state_fips", "cbsa_code"),
    "foundation.market_county_geometry"
  ),
  cbsa_geom = validate_columns(
    sf::st_drop_geometry(cbsa_sf),
    c("cbsa_code", "cbsa_name"),
    "foundation.market_cbsa_geometry"
  )
)

key_checks <- list(
  tract_features = validate_unique_key(tract_features, "tract_geoid", "foundation.tract_features"),
  cbsa_features_target_year = validate_unique_key(
    cbsa_features %>% filter(year == TARGET_YEAR),
    "cbsa_code",
    "foundation.cbsa_features_target_year"
  )
)

null_checks <- dplyr::bind_rows(
  null_rate_summary(
    tract_features,
    c("land_area_sqmi", "pop_density", "median_gross_rent", "median_home_value"),
    "foundation.tract_features"
  ),
  null_rate_summary(
    cbsa_features,
    c("pop_total", "pop_growth_5yr", "median_gross_rent", "median_home_value"),
    "foundation.cbsa_features"
  )
)

geometry_checks <- list(
  cbsa = validate_sf(cbsa_sf, "foundation.market_cbsa_geometry", GEOMETRY_ASSUMPTIONS$expected_crs_epsg),
  county = validate_sf(county_sf, "foundation.market_county_geometry", GEOMETRY_ASSUMPTIONS$expected_crs_epsg),
  tract = validate_sf(tract_sf, "foundation.market_tract_geometry", GEOMETRY_ASSUMPTIONS$expected_crs_epsg)
)

report <- list(
  run_metadata = run_metadata(),
  market_context = market_context,
  output_dir = section_output_dir,
  market_profile_check = market_profile_check,
  target_cbsa = TARGET_CBSA,
  target_year = TARGET_YEAR,
  column_checks = column_checks,
  key_checks = key_checks,
  null_checks = null_checks,
  geometry_checks = geometry_checks,
  pass = all(vapply(column_checks, `[[`, logical(1), "pass")) &&
    isTRUE(market_profile_check$pass) &&
    all(vapply(key_checks, `[[`, logical(1), "pass")) &&
    all(vapply(geometry_checks, `[[`, logical(1), "pass"))
)

save_artifact(
  report,
  resolve_output_path("01_setup", "section_01_validation_report")
)

if (!isTRUE(report$pass)) {
  stop("Notebook-build Section 01 checks failed. See section_01_validation_report.rds for details.", call. = FALSE)
}

message("Notebook-build Section 01 checks complete.")
