# Notebook-build Section 04 script
# Purpose: Read published zone tables and emit Section 04 compatibility artifacts.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()
source("notebooks/retail_opportunity_finder/notebook_build/_shared/read_only_build_helpers.R")

message("Running notebook_build section 04 build: 04_zones")

profile <- get_market_profile()
con <- connect_project_duckdb(read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

assert_duckdb_tables(
  con,
  c(
    "zones.zone_input_candidates",
    "zones.contiguity_zone_components",
    "zones.contiguity_zone_summary",
    "zones.contiguity_zone_geometries"
  )
)

zone_input_candidates <- read_market_sf_table(
  con,
  "zones.zone_input_candidates",
  profile = profile,
  order_sql = "tract_rank, tract_geoid"
) %>%
  drop_platform_metadata()

zone_candidate_tracts <- zone_input_candidates %>%
  sf::st_drop_geometry() %>%
  select(tract_geoid, zone_candidate) %>%
  distinct(tract_geoid, .keep_all = TRUE)

zone_components <- read_market_table(
  con,
  "zones.contiguity_zone_components",
  profile = profile,
  order_sql = "zone_component_id, tract_geoid"
) %>%
  drop_platform_metadata()

component_summary <- zone_components %>%
  count(zone_component_id, zone_component_label, name = "tract_count") %>%
  arrange(zone_component_id)

zones <- read_market_sf_table(
  con,
  "zones.contiguity_zone_geometries",
  profile = profile,
  order_sql = "zone_order"
) %>%
  drop_platform_metadata() %>%
  arrange(zone_order)

zone_labels <- zones %>%
  sf::st_drop_geometry() %>%
  select(any_of(c("zone_component_id", "zone_order", "zone_id", "zone_label", "tract_count", "mean_tract_score")))

zone_summary <- read_market_table(
  con,
  "zones.contiguity_zone_summary",
  profile = profile,
  order_sql = "zone_order"
) %>%
  drop_platform_metadata()

adjacency_edges <- build_contiguity_adjacency_edges(zone_input_candidates)

readiness_report <- list(
  run_metadata = run_metadata(),
  source_mode = "duckdb_published_zones",
  schema_checks = list(
    zone_input_candidates = validate_columns(
      sf::st_drop_geometry(zone_input_candidates),
      c("tract_geoid", "eligible_v1", "tract_score", "tract_rank", "zone_candidate"),
      "zones.zone_input_candidates"
    ),
    zone_components = validate_columns(
      zone_components,
      c("tract_geoid", "zone_component_id", "zone_component_label"),
      "zones.contiguity_zone_components"
    )
  ),
  key_checks = list(
    zone_input_candidates = validate_unique_key(
      sf::st_drop_geometry(zone_input_candidates),
      "tract_geoid",
      "zones.zone_input_candidates"
    ),
    zone_components = validate_unique_key(
      zone_components,
      "tract_geoid",
      "zones.contiguity_zone_components"
    )
  ),
  geometry_checks = list(
    zone_input_candidates = validate_sf(
      zone_input_candidates,
      "zones.zone_input_candidates",
      GEOMETRY_ASSUMPTIONS$expected_crs_epsg
    )
  ),
  counts = list(
    zone_input_candidates = nrow(zone_input_candidates),
    zone_candidate_tracts = nrow(zone_candidate_tracts),
    adjacency_edges = nrow(adjacency_edges),
    zone_components = nrow(zone_components),
    component_summary = nrow(component_summary),
    zones = nrow(zones),
    zone_summary = nrow(zone_summary)
  ),
  pass = TRUE
)

save_artifact(
  zone_input_candidates,
  resolve_output_path("04_zones", "section_04_zone_input_candidates")
)
save_artifact(
  readiness_report,
  resolve_output_path("04_zones", "section_04_input_readiness_report")
)
save_artifact(
  zone_candidate_tracts,
  resolve_output_path("04_zones", "section_04_zone_candidate_tracts")
)
save_artifact(
  adjacency_edges,
  resolve_output_path("04_zones", "section_04_adjacency_edges")
)
save_artifact(
  zone_components,
  resolve_output_path("04_zones", "section_04_zone_components")
)
save_artifact(
  component_summary,
  resolve_output_path("04_zones", "section_04_component_summary")
)
save_artifact(
  zones,
  resolve_output_path("04_zones", "section_04_zones")
)
save_artifact(
  zone_labels,
  resolve_output_path("04_zones", "section_04_zone_labels")
)
save_artifact(
  zone_summary,
  resolve_output_path("04_zones", "section_04_zone_summary")
)

message("Notebook-build Section 04 compatibility artifacts complete.")
