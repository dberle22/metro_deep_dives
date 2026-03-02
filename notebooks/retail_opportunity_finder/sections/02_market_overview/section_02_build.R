# Section 02 build script
# Purpose: data prep and core transformations for section 02_market_overview.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 02 build: 02_market_overview")

project_root <- resolve_project_root()
con <- connect_project_duckdb(read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

target_year <- TARGET_YEAR
target_cbsa_code <- TARGET_CBSA

cbsa_features_sql <- file.path(project_root, "notebooks/retail_opportunity_finder/cbsa_features.sql")
cbsa_features <- query_df_sql_file(con, cbsa_features_sql)

assert_required_columns(cbsa_features, REQUIRED_COLUMNS$cbsa_features, "cbsa_features")

format_kpi_value <- function(x, type = c("num", "pct", "usd", "units", "mins")) {
  type <- match.arg(type)
  if (length(x) == 0 || all(is.na(x))) return(NA_character_)
  v <- x[1]
  if (type == "pct" && !is.na(v) && abs(v) > 1) v <- v / 100
  dplyr::case_when(
    type == "num" ~ scales::comma(v, accuracy = 1),
    type == "pct" ~ scales::percent(v, accuracy = 0.1),
    type == "usd" ~ scales::dollar(v, accuracy = 1),
    type == "units" ~ scales::number(v, accuracy = 0.1),
    type == "mins" ~ scales::number(v, accuracy = 0.1),
    TRUE ~ as.character(v)
  )
}

jax_row <- cbsa_features %>%
  filter(cbsa_code == target_cbsa_code, year == target_year) %>%
  slice(1)

if (nrow(jax_row) != 1) {
  stop("Expected one Jacksonville row in cbsa_features for target year.", call. = FALSE)
}

kpi_tiles <- jax_row %>%
  transmute(
    cbsa_code,
    year,
    population = pop_total,
    pop_growth_5yr = pop_growth_5yr,
    units_per_1k_3yr = bps_units_per_1k_3yr_avg,
    median_rent = median_gross_rent,
    median_home_value = median_home_value,
    mean_commute_min = mean_travel_time
  ) %>%
  mutate(
    population_fmt = format_kpi_value(population, "num"),
    pop_growth_5yr_fmt = format_kpi_value(pop_growth_5yr, "pct"),
    units_per_1k_3yr_fmt = format_kpi_value(units_per_1k_3yr, "units"),
    median_rent_fmt = format_kpi_value(median_rent, "usd"),
    median_home_value_fmt = format_kpi_value(median_home_value, "usd"),
    mean_commute_min_fmt = paste0(format_kpi_value(mean_commute_min, "mins"), " min")
  )

peer_cbsa_codes <- c(
  "27260", # Jacksonville
  "48900", # Wilmington
  "42340", # Savannah
  "39580", # Raleigh
  "24860"  # Greenville
)

peer_table <- cbsa_features %>%
  filter(cbsa_code %in% peer_cbsa_codes, year == target_year) %>%
  transmute(
    cbsa_code,
    metro_name = cbsa_name,
    pop_growth_5yr,
    pop_growth_rank = region_pop_growth_5yr_rank,
    units_per_1k_3yr = bps_units_per_1k_3yr_avg,
    units_per_1k_rank = region_units_1k_avg_rank,
    median_rent = median_gross_rent,
    median_rent_rank = region_gross_rent_rank,
    median_home_value,
    home_value_rank = region_home_value_rank,
    mean_travel_time = round(mean_travel_time, 2),
    mean_travel_time_rank = region_travel_time_rank
  )

jax_bench <- jax_row %>%
  transmute(
    geo_level = "metro",
    geo_name = cbsa_name,
    year,
    population = pop_total,
    pop_growth_5yr,
    units_per_1k_3yr = bps_units_per_1k_3yr_avg,
    median_gross_rent,
    median_home_value,
    mean_travel_time
  )

region_bench <- cbsa_features %>%
  filter(year == target_year, census_division == "South Atlantic") %>%
  summarise(
    geo_level = "region",
    geo_name = "South Atlantic",
    year = target_year,
    population = mean(pop_total, na.rm = TRUE),
    pop_growth_5yr = weighted.mean(pop_growth_5yr, pop_total, na.rm = TRUE),
    units_per_1k_3yr = weighted.mean(bps_units_per_1k_3yr_avg, pop_total, na.rm = TRUE),
    median_gross_rent = weighted.mean(median_gross_rent, pop_total, na.rm = TRUE),
    median_home_value = weighted.mean(median_home_value, pop_total, na.rm = TRUE),
    mean_travel_time = weighted.mean(mean_travel_time, pop_total, na.rm = TRUE)
  )

us_bench <- cbsa_features %>%
  filter(year == target_year) %>%
  summarise(
    geo_level = "us",
    geo_name = "United States (CBSAs)",
    year = target_year,
    population = mean(pop_total, na.rm = TRUE),
    pop_growth_5yr = weighted.mean(pop_growth_5yr, pop_total, na.rm = TRUE),
    units_per_1k_3yr = weighted.mean(bps_units_per_1k_3yr_avg, pop_total, na.rm = TRUE),
    median_gross_rent = weighted.mean(median_gross_rent, pop_total, na.rm = TRUE),
    median_home_value = weighted.mean(median_home_value, pop_total, na.rm = TRUE),
    mean_travel_time = weighted.mean(mean_travel_time, pop_total, na.rm = TRUE)
  )

benchmark_table <- bind_rows(jax_bench, region_bench, us_bench) %>%
  mutate(order = dplyr::case_when(
    geo_level == "metro" ~ 1L,
    geo_level == "region" ~ 2L,
    geo_level == "us" ~ 3L,
    TRUE ~ 99L
  )) %>%
  arrange(order) %>%
  select(-order)

region_vals <- benchmark_table %>% filter(geo_level == "region") %>% slice(1)
us_vals <- benchmark_table %>% filter(geo_level == "us") %>% slice(1)

benchmark_table <- benchmark_table %>%
  mutate(
    mean_travel_time = round(mean_travel_time, 2),
    jax_vs_region_pop = if_else(geo_level == "metro", population / region_vals$population, NA_real_),
    jax_vs_us_pop = if_else(geo_level == "metro", population / us_vals$population, NA_real_),
    jax_vs_region_rent = if_else(geo_level == "metro", median_gross_rent / region_vals$median_gross_rent, NA_real_),
    jax_vs_us_rent = if_else(geo_level == "metro", median_gross_rent / us_vals$median_gross_rent, NA_real_)
  )

pop_trend <- bind_rows(
  cbsa_features %>%
    filter(cbsa_code == target_cbsa_code) %>%
    transmute(geo = "Jacksonville", year, population = as.numeric(pop_total)),
  cbsa_features %>%
    filter(census_division == "South Atlantic") %>%
    group_by(year) %>%
    summarise(population = sum(as.numeric(pop_total), na.rm = TRUE), .groups = "drop") %>%
    mutate(geo = "South Atlantic") %>%
    select(geo, year, population),
  cbsa_features %>%
    group_by(year) %>%
    summarise(population = sum(as.numeric(pop_total), na.rm = TRUE), .groups = "drop") %>%
    mutate(geo = "United States (CBSAs)") %>%
    select(geo, year, population)
) %>%
  distinct(geo, year, .keep_all = TRUE)

baseline_year <- pop_trend %>%
  group_by(geo) %>%
  summarise(min_year = min(year, na.rm = TRUE), .groups = "drop") %>%
  summarise(baseline = max(min_year)) %>%
  pull(baseline)

pop_trend_indexed <- pop_trend %>%
  group_by(geo) %>%
  arrange(year) %>%
  mutate(
    base = population[year == baseline_year][1],
    pop_index = 100 * population / base
  ) %>%
  ungroup()

winsorize_vec <- function(x, probs = c(0.01, 0.99)) {
  qs <- stats::quantile(x, probs = probs, na.rm = TRUE, names = FALSE)
  pmin(pmax(x, qs[1]), qs[2])
}

do_winsorize <- FALSE
winsor_limits <- c(0.01, 0.99)

metro_2024 <- cbsa_features %>%
  filter(year == target_year, cbsa_type == "Metro Area") %>%
  transmute(
    cbsa_geoid = cbsa_code,
    metro_name = cbsa_name,
    pop_total,
    pop_growth_5yr,
    units_per_1k_3yr = bps_units_per_1k_3yr_avg,
    land_area_sq_mi,
    median_gross_rent,
    median_home_value,
    mean_travel_time,
    pct_commute_wfh,
    commute_intensity_b,
    pop_density = if_else(land_area_sq_mi > 0, as.numeric(pop_total) / as.numeric(land_area_sq_mi), NA_real_),
    is_jax = cbsa_code == target_cbsa_code
  )

distribution_long <- metro_2024 %>%
  select(
    cbsa_geoid, metro_name, is_jax,
    pop_growth_5yr,
    units_per_1k_3yr,
    pop_density,
    median_gross_rent,
    median_home_value
  ) %>%
  tidyr::pivot_longer(
    cols = -c(cbsa_geoid, metro_name, is_jax),
    names_to = "metric",
    values_to = "value"
  ) %>%
  filter(!is.na(value))

growth_median <- distribution_long %>%
  filter(metric == "pop_growth_5yr") %>%
  summarise(m = median(value, na.rm = TRUE)) %>%
  pull(m)

if (!is.na(growth_median) && growth_median > 1) {
  distribution_long <- distribution_long %>%
    mutate(value = if_else(metric == "pop_growth_5yr", value / 100, value))
}

if (do_winsorize) {
  distribution_long <- distribution_long %>%
    group_by(metric) %>%
    mutate(value_plot = winsorize_vec(value, winsor_limits)) %>%
    ungroup()
} else {
  distribution_long <- distribution_long %>%
    mutate(value_plot = value)
}

metric_labels <- c(
  pop_growth_5yr = "Pop growth (5y)",
  units_per_1k_3yr = "Units per 1k (3y)",
  pop_density = "Density (per sq mi)",
  median_gross_rent = "Median rent",
  median_home_value = "Median home value"
)

metric_order <- c(
  "pop_growth_5yr",
  "units_per_1k_3yr",
  "pop_density",
  "median_gross_rent",
  "median_home_value"
)

distribution_long <- distribution_long %>%
  mutate(
    metric = factor(metric, levels = metric_order),
    metric_label = metric_labels[as.character(metric)]
  )

save_artifact(
  kpi_tiles,
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_kpi_tiles.rds"
)
save_artifact(
  peer_table,
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_peer_table.rds"
)
save_artifact(
  benchmark_table,
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_benchmark_table.rds"
)
save_artifact(
  pop_trend_indexed,
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_pop_trend_indexed.rds"
)
save_artifact(
  distribution_long,
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_distribution_long.rds"
)
save_artifact(
  cbsa_features,
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_cbsa_features.rds"
)

# Market context map artifact: tract geometries for target CBSA with growth signal.
tract_features_sql <- file.path(project_root, "notebooks/retail_opportunity_finder/tract_features.sql")
tract_features <- query_df_sql_file(con, tract_features_sql) %>%
  filter(as.character(cbsa_code) == as.character(target_cbsa_code)) %>%
  select(tract_geoid, cbsa_code, county_geoid, pop_growth_3yr, pop_growth_5yr, pop_density, median_gross_rent, median_home_value)

tract_wkb <- DBI::dbGetQuery(con, glue::glue("
  WITH cbsa_counties AS (
    SELECT DISTINCT county_geoid, cbsa_code
    FROM metro_deep_dive.silver.xwalk_cbsa_county
    WHERE cbsa_code = '{target_cbsa_code}'
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
    ST_AsWKB(geo.geom) AS geom_wkb
  FROM metro_deep_dive.geo.tracts_fl geo
  INNER JOIN tracts_final tr ON geo.tract_geoid = tr.tract_geoid
"))

wkb_list <- tract_wkb$geom_wkb
if (inherits(wkb_list, "blob")) wkb_list <- lapply(wkb_list, function(x) x)

tract_geom <- sf::st_as_sfc(structure(wkb_list, class = "WKB"), crs = GEOMETRY_ASSUMPTIONS$expected_crs_epsg)
market_tract_sf <- sf::st_sf(
  tract_geoid = tract_wkb$tract_geoid,
  geometry = tract_geom
) %>%
  left_join(tract_features, by = "tract_geoid")

save_artifact(
  market_tract_sf,
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_market_tract_sf.rds"
)

# County context map artifact: county geometries within target CBSA.
county_wkb <- DBI::dbGetQuery(con, glue::glue("
  WITH cbsa_counties AS (
    SELECT DISTINCT county_geoid
    FROM metro_deep_dive.silver.xwalk_cbsa_county
    WHERE cbsa_code = '{target_cbsa_code}'
  )
  SELECT
    county_geoid,
    county_name,
    ST_AsWKB(geom) AS geom_wkb
  FROM metro_deep_dive.geo.counties
  WHERE county_geoid IN (SELECT county_geoid FROM cbsa_counties)
"))

county_wkb_list <- county_wkb$geom_wkb
if (inherits(county_wkb_list, "blob")) county_wkb_list <- lapply(county_wkb_list, function(x) x)

county_geom <- sf::st_as_sfc(structure(county_wkb_list, class = "WKB"), crs = GEOMETRY_ASSUMPTIONS$expected_crs_epsg)
market_county_sf <- sf::st_sf(
  county_geoid = county_wkb$county_geoid,
  county_name = county_wkb$county_name,
  geometry = county_geom
)

save_artifact(
  market_county_sf,
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_market_county_sf.rds"
)

message("Section 02 build complete.")
