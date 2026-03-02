# Section 02 checks script
# Purpose: sanity checks and QA assertions for section outputs.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 02 checks: 02_market_overview")

kpi_tiles <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_kpi_tiles.rds")
peer_table <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_peer_table.rds")
benchmark_table <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_benchmark_table.rds")
pop_trend_indexed <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_pop_trend_indexed.rds")
distribution_long <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_distribution_long.rds")
market_tract_sf <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_market_tract_sf.rds")
market_county_sf <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_market_county_sf.rds")

kpi_check <- validate_columns(
  kpi_tiles,
  c(
    "cbsa_code", "year", "population", "pop_growth_5yr", "units_per_1k_3yr",
    "median_rent", "median_home_value", "mean_commute_min",
    "population_fmt", "pop_growth_5yr_fmt", "units_per_1k_3yr_fmt",
    "median_rent_fmt", "median_home_value_fmt", "mean_commute_min_fmt"
  ),
  "section_02_kpi_tiles"
)

peer_check <- validate_columns(
  peer_table,
  c(
    "cbsa_code", "metro_name", "pop_growth_5yr", "pop_growth_rank",
    "units_per_1k_3yr", "units_per_1k_rank", "median_rent",
    "median_rent_rank", "median_home_value", "home_value_rank",
    "mean_travel_time", "mean_travel_time_rank"
  ),
  "section_02_peer_table"
)

benchmark_check <- validate_columns(
  benchmark_table,
  c(
    "geo_level", "geo_name", "year", "population", "pop_growth_5yr",
    "units_per_1k_3yr", "median_gross_rent", "median_home_value",
    "mean_travel_time"
  ),
  "section_02_benchmark_table"
)

trend_check <- validate_columns(
  pop_trend_indexed,
  c("geo", "year", "population", "base", "pop_index"),
  "section_02_pop_trend_indexed"
)

distribution_check <- validate_columns(
  distribution_long,
  c("cbsa_geoid", "metro_name", "is_jax", "metric", "value", "value_plot", "metric_label"),
  "section_02_distribution_long"
)

market_tract_check <- validate_columns(
  market_tract_sf,
  c("tract_geoid", "cbsa_code", "county_geoid", "pop_growth_3yr", "pop_growth_5yr", "geometry"),
  "section_02_market_tract_sf"
)

market_tract_geom_check <- validate_sf(
  market_tract_sf,
  "section_02_market_tract_sf",
  GEOMETRY_ASSUMPTIONS$expected_crs_epsg
)

market_county_check <- validate_columns(
  market_county_sf,
  c("county_geoid", "county_name", "geometry"),
  "section_02_market_county_sf"
)

market_county_geom_check <- validate_sf(
  market_county_sf,
  "section_02_market_county_sf",
  GEOMETRY_ASSUMPTIONS$expected_crs_epsg
)

logic_checks <- list(
  kpi_single_row = nrow(kpi_tiles) == 1L,
  kpi_target_cbsa = kpi_tiles$cbsa_code[1] == TARGET_CBSA,
  peer_has_jax = any(peer_table$cbsa_code == TARGET_CBSA),
  benchmark_levels = setequal(unique(benchmark_table$geo_level), c("metro", "region", "us")),
  trend_geos = setequal(unique(pop_trend_indexed$geo), c("Jacksonville", "South Atlantic", "United States (CBSAs)")),
  trend_index_finite = all(is.finite(pop_trend_indexed$pop_index)),
  distribution_has_jax = any(distribution_long$is_jax),
  distribution_metrics = setequal(
    as.character(unique(distribution_long$metric)),
    c("pop_growth_5yr", "units_per_1k_3yr", "pop_density", "median_gross_rent", "median_home_value")
  ),
  market_tract_has_rows = nrow(market_tract_sf) > 0,
  market_county_has_rows = nrow(market_county_sf) > 0
)

report <- list(
  run_metadata = run_metadata(),
  checks = list(
    kpi_check = kpi_check,
    peer_check = peer_check,
    benchmark_check = benchmark_check,
    trend_check = trend_check,
    distribution_check = distribution_check,
    market_tract_check = market_tract_check,
    market_tract_geom_check = market_tract_geom_check,
    market_county_check = market_county_check,
    market_county_geom_check = market_county_geom_check
  ),
  logic_checks = logic_checks
)

save_artifact(
  report,
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_validation_report.rds"
)

schema_pass <- all(vapply(report$checks, `[[`, logical(1), "pass"))
logic_pass <- all(unlist(logic_checks))

if (!schema_pass || !logic_pass) {
  stop("Section 02 checks failed. See section_02_validation_report.rds for details.", call. = FALSE)
}

message("Section 02 checks complete.")
