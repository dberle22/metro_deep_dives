# Section 03 build script
# Purpose: data prep and core transformations for section 03_eligibility_scoring.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 03 build: 03_eligibility_scoring")

project_root <- resolve_project_root()
con <- connect_project_duckdb(read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

tract_features_sql <- file.path(project_root, "notebooks/retail_opportunity_finder/tract_features.sql")
tract_features <- query_df_sql_file(con, tract_features_sql)
assert_required_columns(tract_features, REQUIRED_COLUMNS$tract_features, "tract_features")

weights <- MODEL_PARAMS$weights
target_cbsa <- TARGET_CBSA
top_n <- MODEL_PARAMS$top_n_tracts

funnel_counts <- dplyr::tibble(
  step = c(
    "All tracts",
    "After growth gate",
    "After growth + price gates",
    "After growth + price + density gates",
    "Eligible (v1)"
  ),
  step_order = 1:5,
  tracts_remaining = c(
    nrow(tract_features),
    sum(tract_features$gate_pop == 1, na.rm = TRUE),
    sum(tract_features$gate_pop == 1 & tract_features$gate_price == 1, na.rm = TRUE),
    sum(tract_features$gate_pop == 1 & tract_features$gate_price == 1 & tract_features$gate_density == 1, na.rm = TRUE),
    sum(tract_features$eligible_v1 == 1, na.rm = TRUE)
  )
)

eligible_tracts <- tract_features %>%
  filter(eligible_v1 == 1) %>%
  mutate(
    growth_raw = pop_growth_5yr,
    units_raw = units_per_1k_3yr,
    headroom_raw = -pop_density,
    price_raw = -price_proxy_pctl,
    commute_raw = commute_intensity_b
  )

impute_with_median <- function(x) {
  med <- stats::median(x, na.rm = TRUE)
  dplyr::if_else(is.na(x), med, x)
}

scored_tracts <- eligible_tracts %>%
  mutate(
    growth_scoring = impute_with_median(growth_raw),
    units_scoring = impute_with_median(units_raw),
    headroom_scoring = impute_with_median(headroom_raw),
    price_scoring = impute_with_median(price_raw),
    commute_scoring = impute_with_median(commute_raw)
  ) %>%
  mutate(
    z_growth = zscore(growth_scoring),
    z_units = zscore(units_scoring),
    z_headroom = zscore(headroom_scoring),
    z_price = zscore(price_scoring),
    z_commute = zscore(commute_scoring)
  ) %>%
  mutate(
    contrib_growth = weights[["growth"]] * z_growth,
    contrib_units = weights[["units"]] * z_units,
    contrib_headroom = weights[["headroom"]] * z_headroom,
    contrib_price = weights[["price"]] * z_price,
    contrib_commute = weights[["commute"]] * z_commute,
    tract_score = contrib_growth + contrib_units + contrib_headroom + contrib_price + contrib_commute
  ) %>%
  arrange(desc(tract_score)) %>%
  mutate(
    tract_rank = row_number()
  )

make_why_tags <- function(df) {
  growth_cut <- stats::quantile(df$pop_growth_5yr, 0.75, na.rm = TRUE)
  units_cut <- stats::quantile(df$units_per_1k_3yr, 0.75, na.rm = TRUE)
  commute_cut <- stats::quantile(df$commute_intensity_b, 0.75, na.rm = TRUE)

  df %>%
    mutate(
      why_growth = pop_growth_5yr >= growth_cut,
      why_units = units_per_1k_3yr >= units_cut,
      why_headroom = density_pctl <= MODEL_PARAMS$max_density_percentile,
      why_price = price_proxy_pctl <= 0.50,
      why_commute = commute_intensity_b >= commute_cut
    ) %>%
    rowwise() %>%
    mutate(
      why_tags = paste(
        c(
          if (isTRUE(why_growth)) "High growth" else NA_character_,
          if (isTRUE(why_units)) "High housing pipeline" else NA_character_,
          if (isTRUE(why_headroom)) "Low density headroom" else NA_character_,
          if (isTRUE(why_price)) "Moderate price pressure" else NA_character_,
          if (isTRUE(why_commute)) "High commute exposure" else NA_character_
        ) %>% stats::na.omit(),
        collapse = " | "
      )
    ) %>%
    ungroup() %>%
    mutate(why_tags = if_else(why_tags == "", "Balanced profile", why_tags))
}

scored_tracts <- make_why_tags(scored_tracts)

top_tracts <- scored_tracts %>%
  slice_head(n = top_n) %>%
  select(
    tract_rank,
    tract_geoid,
    tract_score,
    pop_growth_5yr,
    units_per_1k_3yr,
    pop_density,
    price_proxy_pctl,
    commute_intensity_b,
    contrib_growth,
    contrib_units,
    contrib_headroom,
    contrib_price,
    contrib_commute,
    why_tags
  )

tract_component_score_table <- tract_features %>%
  left_join(
    scored_tracts %>%
      select(
        tract_geoid,
        growth_raw,
        units_raw,
        headroom_raw,
        price_raw,
        commute_raw,
        z_growth,
        z_units,
        z_headroom,
        z_price,
        z_commute,
        contrib_growth,
        contrib_units,
        contrib_headroom,
        contrib_price,
        contrib_commute,
        tract_score,
        tract_rank,
        why_tags
      ),
    by = "tract_geoid"
  ) %>%
  mutate(
    cbsa_code = as.character(cbsa_code),
    is_scored = !is.na(tract_score),
    target_cbsa = target_cbsa
  ) %>%
  select(
    target_cbsa,
    cbsa_code,
    county_geoid,
    tract_geoid,
    year,
    eligible_v1,
    gate_pop,
    gate_price,
    gate_density,
    pop_growth_5yr,
    units_per_1k_3yr,
    pop_density,
    price_proxy_pctl,
    commute_intensity_b,
    growth_raw,
    units_raw,
    headroom_raw,
    price_raw,
    commute_raw,
    z_growth,
    z_units,
    z_headroom,
    z_price,
    z_commute,
    contrib_growth,
    contrib_units,
    contrib_headroom,
    contrib_price,
    contrib_commute,
    tract_score,
    tract_rank,
    why_tags,
    is_scored
  )

price_hist_input <- tract_features %>%
  select(tract_geoid, price_proxy_pctl, eligible_v1) %>%
  filter(!is.na(price_proxy_pctl))

growth_hist_input <- tract_features %>%
  select(tract_geoid, pop_growth_5yr, eligible_v1) %>%
  filter(!is.na(pop_growth_5yr))

tract_wkb <- DBI::dbGetQuery(con, glue::glue("
  WITH cbsa_counties AS (
    SELECT DISTINCT county_geoid, cbsa_code
    FROM metro_deep_dive.silver.xwalk_cbsa_county
    WHERE cbsa_code = '{target_cbsa}'
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
tract_sf <- sf::st_sf(
  tract_geoid = tract_wkb$tract_geoid,
  geometry = tract_geom
) %>%
  left_join(
    tract_features %>% select(tract_geoid, eligible_v1),
    by = "tract_geoid"
  )

save_artifact(
  funnel_counts,
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_funnel_counts.rds"
)
save_artifact(
  eligible_tracts,
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_eligible_tracts.rds"
)
save_artifact(
  scored_tracts,
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_scored_tracts.rds"
)
save_artifact(
  top_tracts,
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_top_tracts.rds"
)
save_artifact(
  tract_component_score_table,
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_tract_component_scores.rds"
)
readr::write_csv(
  tract_component_score_table,
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_tract_component_scores.csv"
)
save_artifact(
  price_hist_input,
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_price_hist_input.rds"
)
save_artifact(
  growth_hist_input,
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_growth_hist_input.rds"
)
save_artifact(
  tract_sf,
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_tract_sf.rds"
)

message("Section 03 build complete.")
