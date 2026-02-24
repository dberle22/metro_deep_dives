# Section 01 checks script
# Purpose: sanity checks and QA assertions for section outputs.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 01 checks: 01_setup")

project_root <- resolve_project_root()
con <- connect_project_duckdb(read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

tract_features_sql <- file.path(project_root, "notebooks/retail_opportunity_finder/tract_features.sql")
cbsa_features_sql <- file.path(project_root, "notebooks/retail_opportunity_finder/cbsa_features.sql")

tract_features <- query_df_sql_file(con, tract_features_sql)
cbsa_features <- query_df_sql_file(con, cbsa_features_sql)

cbsa_wkb <- DBI::dbGetQuery(con, glue::glue("
  SELECT
    cbsa_code,
    cbsa_name,
    ST_AsWKB(geom) AS geom_wkb
  FROM metro_deep_dive.geo.cbsas
  WHERE cbsa_code = '{TARGET_CBSA}'
"))

county_wkb <- DBI::dbGetQuery(con, glue::glue("
  WITH cbsa_counties AS (
    SELECT DISTINCT county_geoid, cbsa_code
    FROM metro_deep_dive.silver.xwalk_cbsa_county
    WHERE cbsa_code = '{TARGET_CBSA}'
  )
  SELECT
    c.county_geoid,
    c.county_name,
    c.state_fips,
    cbsa_counties.cbsa_code,
    ST_AsWKB(c.geom) AS geom_wkb
  FROM metro_deep_dive.geo.counties c
  INNER JOIN cbsa_counties ON c.county_geoid = cbsa_counties.county_geoid
"))

tract_wkb <- DBI::dbGetQuery(con, glue::glue("
  WITH cbsa_counties AS (
    SELECT DISTINCT county_geoid, cbsa_code
    FROM metro_deep_dive.silver.xwalk_cbsa_county
    WHERE cbsa_code = '{TARGET_CBSA}'
  ),
  tracts AS (
    SELECT
      tract_geoid,
      printf('%02d%03d', CAST(state_fip AS INTEGER), CAST(county_fip AS INTEGER)) AS county_geoid
    FROM metro_deep_dive.silver.xwalk_tract_county
  ),
  tracts_final AS (
    SELECT t.tract_geoid, t.county_geoid, c.cbsa_code
    FROM tracts t
    JOIN cbsa_counties c ON t.county_geoid = c.county_geoid
  )
  SELECT
    geo.tract_geoid,
    geo.county_geoid,
    geo.state_fips,
    tr.cbsa_code,
    geo.geom_wkb
  FROM metro_deep_dive.geo.tracts_fl geo
  INNER JOIN tracts_final tr ON geo.tract_geoid = tr.tract_geoid
"))

cbsa_sf <- {
  wkb <- cbsa_wkb$geom_wkb[[1]]
  if (inherits(wkb, "blob")) wkb <- wkb[[1]]
  geom <- sf::st_as_sfc(structure(list(wkb), class = "WKB"), crs = GEOMETRY_ASSUMPTIONS$expected_crs_epsg)
  sf::st_sf(cbsa_code = cbsa_wkb$cbsa_code, cbsa_name = cbsa_wkb$cbsa_name, geometry = geom)
}

county_sf <- {
  wkb_list <- county_wkb$geom_wkb
  if (inherits(wkb_list, "blob")) wkb_list <- lapply(wkb_list, function(x) x)
  geom <- sf::st_as_sfc(structure(wkb_list, class = "WKB"), crs = GEOMETRY_ASSUMPTIONS$expected_crs_epsg)
  sf::st_sf(county_wkb[, c("county_geoid", "county_name", "state_fips", "cbsa_code")], geometry = geom)
}

tract_sf <- {
  wkb_list <- tract_wkb$geom_wkb
  if (inherits(wkb_list, "blob")) wkb_list <- lapply(wkb_list, function(x) x)
  geom <- sf::st_as_sfc(structure(wkb_list, class = "WKB"), crs = GEOMETRY_ASSUMPTIONS$expected_crs_epsg)
  sf::st_sf(tract_wkb[, c("tract_geoid", "county_geoid", "state_fips", "cbsa_code")], geometry = geom)
}

column_checks <- list(
  tract_features = validate_columns(tract_features, REQUIRED_COLUMNS$tract_features, "tract_features"),
  cbsa_features = validate_columns(cbsa_features, REQUIRED_COLUMNS$cbsa_features, "cbsa_features"),
  tract_geom = validate_columns(tract_wkb, REQUIRED_COLUMNS$tract_geom, "tract_geom"),
  county_geom = validate_columns(county_wkb, REQUIRED_COLUMNS$county_geom, "county_geom"),
  cbsa_geom = validate_columns(cbsa_wkb, REQUIRED_COLUMNS$cbsa_geom, "cbsa_geom")
)

key_checks <- list(
  tract_features = validate_unique_key(tract_features, "tract_geoid", "tract_features"),
  cbsa_features = validate_unique_key(cbsa_features %>% filter(year == TARGET_YEAR), "cbsa_code", "cbsa_features_target_year")
)

null_checks <- bind_rows(
  null_rate_summary(
    tract_features,
    c("land_area_sqmi", "pop_density", "median_gross_rent", "median_home_value", "pct_commute_wfh", "total_units_3yr_avg"),
    "tract_features"
  ),
  null_rate_summary(
    cbsa_features,
    c("pop_total", "pop_growth_5yr", "median_gross_rent", "median_home_value", "bps_units_per_1k_3yr_avg"),
    "cbsa_features"
  )
)

geometry_checks <- list(
  cbsa = validate_sf(cbsa_sf, "cbsa_sf", GEOMETRY_ASSUMPTIONS$expected_crs_epsg),
  county = validate_sf(county_sf, "county_sf", GEOMETRY_ASSUMPTIONS$expected_crs_epsg),
  tract = validate_sf(tract_sf, "tract_sf", GEOMETRY_ASSUMPTIONS$expected_crs_epsg)
)

report <- list(
  run_metadata = run_metadata(),
  target_cbsa = TARGET_CBSA,
  target_year = TARGET_YEAR,
  column_checks = column_checks,
  key_checks = key_checks,
  null_checks = null_checks,
  geometry_checks = geometry_checks
)

save_artifact(
  report,
  "notebooks/retail_opportunity_finder/sections/01_setup/outputs/section_01_validation_report.rds"
)

all_pass <- all(vapply(column_checks, `[[`, logical(1), "pass")) &&
  all(vapply(key_checks, `[[`, logical(1), "pass")) &&
  all(vapply(geometry_checks, `[[`, logical(1), "pass"))

if (!all_pass) {
  stop("Section 01 checks failed. See section_01_validation_report.rds for details.", call. = FALSE)
}

message("Section 01 checks complete.")
