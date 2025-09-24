# Create Constant-Geometry Metro Data based on Counties in 2023

# Load Packages ----
# In the future we should update this to read from a requirements file
library(tidyverse)
library(janitor)
library(readr)
library(lubridate)
library(glue)
library(scales)
library(sf)
library(tigris)
library(stringr)
library(fmsb)
library(patchwork)
library(viridis)

# Set Paths ----
# Make sure we're reading from the project Renviron
if (file.exists(".Renviron")) readRenviron(".Renviron")

# ---- Resolve base directories from .Renviron first, then optional config/paths.R ----
get_env_path <- function(key) {
  val <- Sys.getenv(key, unset = "")
  if (!nzchar(val)) return(NA_character_)
  path.expand(val)
}

# Expected keys in your .Renviron (project or user):
# SILVER_CBSA, SILVER_COUNTY, GOLD_XWALK, GOLD_CBSA
silver_cbsa_env <- get_env_path("SILVER_CBSA")
silver_county_env <- get_env_path("SILVER_COUNTY")
gold_xwalk_env <- get_env_path("GOLD_XWALK")
gold_cbsa_env <- get_env_path("GOLD_CBSA")
gold_county_env <- get_env_path("GOLD_COUNTY")

# Set Parameters ----
base_year <- 2023
years <- 2013:2023 # Set the years here


# Read in County level Data: ACS, BEA GDP, BEA Income ----
# ACS Population
county_acs <- readr::read_csv(file.path(silver_county_env, "acs_county_5_year.csv"), show_col_types = FALSE) %>%
  janitor::clean_names() %>%
  dplyr::mutate(county_fips = as.character(geoid)) %>%
  dplyr::select(county_fips, year, pop_total_e)

county_gdp <- readr::read_csv(file.path(silver_county_env, "bea_county_gdp_summary.csv"), show_col_types = FALSE) %>%
  janitor::clean_names() %>%
  dplyr::mutate(county_fips = as.character(geo_fips)) %>%
  dplyr::select(county_fips, year, gdp_chained2017)

county_inc <- readr::read_csv(file.path(silver_county_env, "bea_county_personal_income.csv"), show_col_types = FALSE) %>%
  janitor::clean_names() %>%
  dplyr::mutate(county_fips = as.character(geo_fips)) %>%
  dplyr::select(county_fips, year, personal_income) %>%
  dplyr::mutate(inc_thousands = personal_income / 1000)

xwalk <- readr::read_csv(file.path(gold_xwalk_env, "cbsa_county_crosswalk.csv"), show_col_types = FALSE) %>%
  janitor::clean_names() %>%
  dplyr::mutate(cbsa_geoid = as.character(cbsa_code), county_fips = as.character(county_geoid)) %>%
  dplyr::select(cbsa_geoid, county_fips)

cbsa_meta <- readr::read_csv(file.path(gold_cbsa_env, "cbsa_metadata.csv"), show_col_types = FALSE) %>%
  janitor::clean_names() %>%
  dplyr::mutate(cbsa_geoid = as.character(geoid)) %>%
  dplyr::select(cbsa_geoid, year, cbsa_name, cbsa_type, primary_state, division, region)


# Load Functions ----
#' Rebase CBSA metrics from county-level data
#'
#' @param df Tibble with county-level observations including `cbsa_code`, `year`, and metric columns.
#' @param weight_col Column to use for weighting county contributions.
#'
#' @return A tibble summarising CBSA-level metrics.
#' @export
rebase_cbsa_from_counties <- function(df, weight_col = NULL) {
  stopifnot("cbsa_code" %in% names(df))
  stopifnot("year" %in% names(df))
  
  if (!is.null(weight_col)) {
    weight_sym <- rlang::sym(weight_col)
  } else {
    weight_sym <- rlang::sym("weight")
    df <- df |> dplyr::mutate(weight = 1)
  }
  
  numeric_cols <- names(dplyr::select(df, dplyr::where(is.numeric)))
  metric_cols <- setdiff(numeric_cols, rlang::as_string(weight_sym))
  
  df |>
    dplyr::group_by(cbsa_code, year) |>
    dplyr::summarise(
      dplyr::across(
        dplyr::all_of(metric_cols),
        ~stats::weighted.mean(.x, !!weight_sym, na.rm = TRUE)
      ),
      .groups = "drop"
    )
}

weighted_median <- function(x, w) {
  ok <- is.finite(x) & is.finite(w) & w >= 0
  x <- x[ok]; w <- w[ok]
  if (!length(x)) return(NA_real_)
  ord <- order(x); x <- x[ord]; w <- w[ord]
  cw <- cumsum(w) / sum(w)
  x[which(cw >= 0.5)[1]]
}

sum_by_cbsa <- function(df, value_col, base_membership, years) {
  nm <- rlang::ensym(value_col)
  df %>%
    dplyr::semi_join(base_membership, by = "county_fips") %>%
    dplyr::filter(year %in% years) %>%
    dplyr::inner_join(base_membership, by = "county_fips") %>%
    dplyr::group_by(cbsa_geoid, year) %>%
    dplyr::summarise(!!rlang::as_string(nm) := sum(!!nm, na.rm = TRUE), .groups = "drop")
}

weighted_median_by_cbsa <- function(df, value_col, weight_col, base_membership, years) {
  v <- rlang::ensym(value_col); w <- rlang::ensym(weight_col)
  df %>%
    dplyr::semi_join(base_membership, by = "county_fips") %>%
    dplyr::filter(year %in% years) %>%
    dplyr::inner_join(base_membership, by = "county_fips") %>%
    dplyr::group_by(cbsa_geoid, year) %>%
    dplyr::summarise(!!rlang::as_string(v) := weighted_median(!!v, !!w), .groups = "drop")
}

# Recalculate metrics using the County level data ----
cbsa_pop <- sum_by_cbsa(county_acs, pop_total_e, xwalk, years) %>%
  dplyr::rename(population = pop_total_e)

cbsa_gdp <- sum_by_cbsa(county_gdp, gdp_chained2017, xwalk, years) %>%
  dplyr::rename(gdp_thousands = gdp_chained2017)

cbsa_inc <- sum_by_cbsa(county_inc, inc_thousands, xwalk, years)

# Long data frame + metadata ----
cbsa_const_long <- cbsa_pop %>%
  dplyr::left_join(cbsa_meta %>% select(-year), by = c("cbsa_geoid")) %>%
  dplyr::left_join(cbsa_gdp, by = c("cbsa_geoid","year")) %>%
  dplyr::left_join(cbsa_inc, by = c("cbsa_geoid","year")) %>%
  dplyr::arrange(cbsa_geoid, year) %>%
  dplyr::mutate(
    gdp_pc = (gdp_thousands * 1000) / population,
    inc_pc = (inc_thousands * 1000) / population
  ) %>%
  add_growth_cols(id_cols = c("cbsa_geoid"), year = "year", value_col = "population",    horizons = c(5,10), prefix = "pop_") %>%
  add_growth_cols(id_cols = c("cbsa_geoid"), year = "year",  value_col = "gdp_thousands", horizons = c(5,10), prefix = "gdp_") %>%
  add_growth_cols(id_cols = c("cbsa_geoid"), year = "year",  value_col = "gdp_pc",        horizons = c(5,10), prefix = "gdp_pc_") %>%
  add_growth_cols(id_cols = c("cbsa_geoid"), year = "year",  value_col = "inc_thousands", horizons = c(5,10), prefix = "inc_") %>%
  add_growth_cols(id_cols = c("cbsa_geoid"), year = "year",  value_col = "inc_pc",        horizons = c(5,10), prefix = "inc_pc_")

# ---- Latest snapshot + metadata ----
ymx <- max(cbsa_const_long$year, na.rm = TRUE)
cbsa_const_latest <- cbsa_const_long %>%
  dplyr::filter(year == ymx)

cbsa_const_long %>% dplyr::slice_head(n = 5)
cbsa_const_latest %>% dplyr::slice_head(n = 5)

# Write to Data Folder ----
write_csv(cbsa_const_long, "/Users/danberle/Documents/projects/metro_deep_dive/data/gold/overview_cbsa_constant_long.csv")
write_csv(cbsa_const_latest, "/Users/danberle/Documents/projects/metro_deep_dive/data/gold/overview_cbsa_constant_latest.csv")

# Go back to Notebook and recalculate benchmarks