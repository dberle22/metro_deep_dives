# Notebook-build Section 03 script
# Purpose: Read scoring/foundation tables and emit Section 03 compatibility artifacts.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()
source("notebooks/retail_opportunity_finder/notebook_build/_shared/read_only_build_helpers.R")

message("Running notebook_build section 03 build: 03_eligibility_scoring")

profile <- get_market_profile()
con <- connect_project_duckdb(read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

assert_duckdb_tables(
  con,
  c(
    "scoring.tract_scores",
    "scoring.cluster_seed_tracts",
    "foundation.market_tract_geometry"
  )
)

tract_component_scores <- read_market_table(
  con,
  "scoring.tract_scores",
  profile = profile,
  order_sql = "tract_rank"
) %>%
  drop_platform_metadata()

cluster_seed_tracts <- read_market_table(
  con,
  "scoring.cluster_seed_tracts",
  profile = profile,
  order_sql = "cluster_seed_rank"
) %>%
  drop_platform_metadata()

tract_sf <- read_market_sf_table(
  con,
  "foundation.market_tract_geometry",
  profile = profile,
  order_sql = "tract_geoid"
) %>%
  drop_platform_metadata() %>%
  left_join(
    tract_component_scores %>% select(tract_geoid, eligible_v1),
    by = "tract_geoid"
  )

funnel_counts <- tibble::tibble(
  step = c(
    "All tracts",
    "After growth gate",
    "After growth + price gates",
    "After growth + price + density gates",
    "Eligible (v1)"
  ),
  step_order = 1:5,
  tracts_remaining = c(
    nrow(tract_component_scores),
    sum(tract_component_scores$gate_pop == 1, na.rm = TRUE),
    sum(tract_component_scores$gate_pop == 1 & tract_component_scores$gate_price == 1, na.rm = TRUE),
    sum(
      tract_component_scores$gate_pop == 1 &
        tract_component_scores$gate_price == 1 &
        tract_component_scores$gate_density == 1,
      na.rm = TRUE
    ),
    sum(tract_component_scores$eligible_v1 == 1, na.rm = TRUE)
  )
)

eligible_tracts <- tract_component_scores %>%
  filter(eligible_v1 == 1) %>%
  mutate(
    growth_raw = pop_growth_3yr,
    units_raw = units_per_1k_3yr,
    headroom_raw = -pop_density,
    price_raw = -price_proxy_pctl,
    commute_raw = commute_intensity_b,
    income_raw = median_hh_income
  )

scored_tracts <- tract_component_scores %>%
  filter(is_scored) %>%
  arrange(tract_rank)

top_tracts <- scored_tracts %>%
  filter(eligible_v1 == 1) %>%
  arrange(tract_rank) %>%
  slice_head(n = MODEL_PARAMS$top_n_tracts) %>%
  select(
    tract_rank,
    tract_geoid,
    tract_score,
    pop_growth_3yr,
    units_per_1k_3yr,
    pop_density,
    price_proxy_pctl,
    commute_intensity_b,
    median_hh_income,
    contrib_growth,
    contrib_units,
    contrib_headroom,
    contrib_price,
    contrib_commute,
    contrib_income,
    why_tags
  )

price_hist_input <- tract_component_scores %>%
  select(tract_geoid, price_proxy_pctl, eligible_v1) %>%
  filter(!is.na(price_proxy_pctl))

growth_hist_input <- tract_component_scores %>%
  select(tract_geoid, pop_growth_3yr, eligible_v1) %>%
  filter(!is.na(pop_growth_3yr))

save_artifact(
  funnel_counts,
  resolve_output_path("03_eligibility_scoring", "section_03_funnel_counts")
)
save_artifact(
  eligible_tracts,
  resolve_output_path("03_eligibility_scoring", "section_03_eligible_tracts")
)
save_artifact(
  scored_tracts,
  resolve_output_path("03_eligibility_scoring", "section_03_scored_tracts")
)
save_artifact(
  top_tracts,
  resolve_output_path("03_eligibility_scoring", "section_03_top_tracts")
)
save_artifact(
  cluster_seed_tracts,
  resolve_output_path("03_eligibility_scoring", "section_03_cluster_seed_tracts")
)
save_artifact(
  tract_component_scores,
  resolve_output_path("03_eligibility_scoring", "section_03_tract_component_scores")
)
readr::write_csv(
  tract_component_scores,
  resolve_output_path("03_eligibility_scoring", "section_03_tract_component_scores", ext = "csv")
)
save_artifact(
  price_hist_input,
  resolve_output_path("03_eligibility_scoring", "section_03_price_hist_input")
)
save_artifact(
  growth_hist_input,
  resolve_output_path("03_eligibility_scoring", "section_03_growth_hist_input")
)
save_artifact(
  tract_sf,
  resolve_output_path("03_eligibility_scoring", "section_03_tract_sf")
)

message("Notebook-build Section 03 compatibility artifacts complete.")
