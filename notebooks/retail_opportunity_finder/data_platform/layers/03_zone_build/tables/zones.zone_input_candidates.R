build_zone_input_candidates <- function(scored_tracts, tract_sf, tract_component_scores, cluster_seed_tracts) {
  scored_required <- c(
    "tract_geoid", "eligible_v1", "tract_score", "tract_rank",
    "pop_total", "pop_growth_3yr", "pop_density", "units_per_1k_3yr", "price_proxy_pctl"
  )
  tract_sf_required <- c("tract_geoid", "eligible_v1")
  component_required <- c(
    "tract_geoid", "eligible_v1", "is_scored",
    "pop_growth_3yr", "pop_density", "units_per_1k_3yr", "price_proxy_pctl"
  )
  cluster_seed_required <- c(
    "tract_geoid", "tract_score", "cluster_seed_rank", "cluster_top_share", "cluster_cutoff_n"
  )

  scored_schema_check <- validate_columns(scored_tracts, scored_required, "section_03_scored_tracts")
  tract_sf_schema_check <- validate_columns(tract_sf, tract_sf_required, "section_03_tract_sf")
  component_schema_check <- validate_columns(tract_component_scores, component_required, "section_03_tract_component_scores")
  cluster_seed_schema_check <- validate_columns(cluster_seed_tracts, cluster_seed_required, "section_03_cluster_seed_tracts")

  scored_key_check <- validate_unique_key(scored_tracts, "tract_geoid", "section_03_scored_tracts")
  tract_sf_key_check <- validate_unique_key(tract_sf, "tract_geoid", "section_03_tract_sf")
  component_key_check <- validate_unique_key(tract_component_scores, "tract_geoid", "section_03_tract_component_scores")
  cluster_seed_key_check <- validate_unique_key(cluster_seed_tracts, "tract_geoid", "section_03_cluster_seed_tracts")
  tract_sf_geom_check <- validate_sf(tract_sf, "section_03_tract_sf", GEOMETRY_ASSUMPTIONS$expected_crs_epsg)

  cluster_seed_from_scored <- scored_tracts %>%
    semi_join(cluster_seed_tracts %>% select(tract_geoid), by = "tract_geoid") %>%
    distinct(tract_geoid)

  cluster_seed_from_components <- tract_component_scores %>%
    semi_join(cluster_seed_tracts %>% select(tract_geoid), by = "tract_geoid") %>%
    distinct(tract_geoid)

  cluster_seed_from_geom <- tract_sf %>%
    sf::st_drop_geometry() %>%
    semi_join(cluster_seed_tracts %>% select(tract_geoid), by = "tract_geoid") %>%
    distinct(tract_geoid)

  missing_scored_in_geom <- setdiff(cluster_seed_from_scored$tract_geoid, cluster_seed_from_geom$tract_geoid)
  missing_geom_in_scored <- setdiff(cluster_seed_from_geom$tract_geoid, cluster_seed_from_scored$tract_geoid)
  missing_component_in_geom <- setdiff(cluster_seed_from_components$tract_geoid, cluster_seed_from_geom$tract_geoid)

  eligible_zone_inputs <- tract_sf %>%
    inner_join(
      scored_tracts %>%
        semi_join(cluster_seed_tracts %>% select(tract_geoid), by = "tract_geoid") %>%
        select(
          tract_geoid,
          tract_score,
          tract_rank,
          pop_total,
          pop_growth_3yr,
          pop_density,
          units_per_1k_3yr,
          price_proxy_pctl
        ),
      by = "tract_geoid"
    ) %>%
    mutate(zone_candidate = TRUE)

  readiness_report <- list(
    run_metadata = run_metadata(),
    schema_checks = list(
      scored_schema_check = scored_schema_check,
      tract_sf_schema_check = tract_sf_schema_check,
      component_schema_check = component_schema_check,
      cluster_seed_schema_check = cluster_seed_schema_check
    ),
    key_checks = list(
      scored_key_check = scored_key_check,
      tract_sf_key_check = tract_sf_key_check,
      component_key_check = component_key_check,
      cluster_seed_key_check = cluster_seed_key_check
    ),
    geometry_checks = list(
      tract_sf_geom_check = tract_sf_geom_check
    ),
    counts = list(
      scored_rows = nrow(scored_tracts),
      tract_sf_rows = nrow(tract_sf),
      component_rows = nrow(tract_component_scores),
      cluster_seed_from_scored = nrow(cluster_seed_from_scored),
      cluster_seed_from_geom = nrow(cluster_seed_from_geom),
      cluster_seed_from_components = nrow(cluster_seed_from_components),
      zone_candidate_rows = nrow(eligible_zone_inputs)
    ),
    set_differences = list(
      missing_scored_in_geom = missing_scored_in_geom,
      missing_geom_in_scored = missing_geom_in_scored,
      missing_component_in_geom = missing_component_in_geom
    ),
    pass = isTRUE(scored_schema_check$pass) &&
      isTRUE(tract_sf_schema_check$pass) &&
      isTRUE(component_schema_check$pass) &&
      isTRUE(scored_key_check$pass) &&
      isTRUE(tract_sf_key_check$pass) &&
      isTRUE(component_key_check$pass) &&
      isTRUE(cluster_seed_schema_check$pass) &&
      isTRUE(cluster_seed_key_check$pass) &&
      isTRUE(tract_sf_geom_check$pass) &&
      length(missing_scored_in_geom) == 0 &&
      length(missing_geom_in_scored) == 0 &&
      length(missing_component_in_geom) == 0
  )

  list(
    eligible_zone_inputs = eligible_zone_inputs,
    zone_candidate_tracts = eligible_zone_inputs %>%
      sf::st_drop_geometry() %>%
      select(tract_geoid) %>%
      mutate(zone_candidate = TRUE) %>%
      distinct(tract_geoid, .keep_all = TRUE),
    readiness_report = readiness_report
  )
}
