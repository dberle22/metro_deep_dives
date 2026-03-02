# Section 04 build script
# Purpose: data prep and core transformations for section 04_zones.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 04 build: 04_zones")

# Step 1: Load and validate Sprint B inputs
scored_tracts <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_scored_tracts.rds")
tract_sf <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_tract_sf.rds")
tract_component_scores <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_tract_component_scores.rds")
cluster_seed_tracts <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_cluster_seed_tracts.rds")

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
  mutate(
    zone_candidate = TRUE
  )

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

save_artifact(
  eligible_zone_inputs,
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_zone_input_candidates.rds"
)

save_artifact(
  readiness_report,
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_input_readiness_report.rds"
)

if (!isTRUE(readiness_report$pass)) {
  stop("Section 04 input readiness checks failed. See section_04_input_readiness_report.rds.", call. = FALSE)
}

message("Section 04 build step 1 complete: inputs loaded and validated.")

# Step 2: Define zone candidate universe (top-scoring cluster seed tracts)
zone_candidate_tracts <- eligible_zone_inputs %>%
  sf::st_drop_geometry() %>%
  select(tract_geoid) %>%
  mutate(
    zone_candidate = TRUE
  ) %>%
  distinct(tract_geoid, .keep_all = TRUE)

if (nrow(zone_candidate_tracts) == 0) {
  stop("No cluster seed tracts available for zone candidate universe.", call. = FALSE)
}

save_artifact(
  zone_candidate_tracts,
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_zone_candidate_tracts.rds"
)

message(glue::glue("Section 04 build step 2 complete: {nrow(zone_candidate_tracts)} cluster seed tracts selected as zone candidates."))

# Step 3: Build tract contiguity graph and connected components
candidate_sf <- eligible_zone_inputs %>%
  arrange(tract_geoid)

neighbor_idx <- sf::st_touches(candidate_sf)
n <- nrow(candidate_sf)

# Build undirected edge list from touches graph
edge_tbl <- lapply(seq_len(n), function(i) {
  nbrs <- neighbor_idx[[i]]
  if (length(nbrs) == 0) return(NULL)
  nbrs <- nbrs[nbrs > i]
  if (length(nbrs) == 0) return(NULL)
  data.frame(
    from_idx = rep(i, length(nbrs)),
    to_idx = nbrs,
    stringsAsFactors = FALSE
  )
}) %>%
  dplyr::bind_rows()

adjacency_edges <- if (nrow(edge_tbl) > 0) {
  edge_tbl %>%
    mutate(
      from_tract_geoid = candidate_sf$tract_geoid[from_idx],
      to_tract_geoid = candidate_sf$tract_geoid[to_idx]
    ) %>%
    select(from_tract_geoid, to_tract_geoid)
} else {
  data.frame(
    from_tract_geoid = character(),
    to_tract_geoid = character(),
    stringsAsFactors = FALSE
  )
}

# Connected components via BFS over neighbor list
component_id <- rep(NA_integer_, n)
current_component <- 0L

for (start in seq_len(n)) {
  if (!is.na(component_id[start])) next
  current_component <- current_component + 1L
  queue <- c(start)
  component_id[start] <- current_component

  while (length(queue) > 0) {
    node <- queue[[1]]
    queue <- queue[-1]
    nbrs <- neighbor_idx[[node]]
    if (length(nbrs) == 0) next
    unassigned <- nbrs[is.na(component_id[nbrs])]
    if (length(unassigned) > 0) {
      component_id[unassigned] <- current_component
      queue <- c(queue, unassigned)
    }
  }
}

zone_components <- candidate_sf %>%
  sf::st_drop_geometry() %>%
  transmute(
    tract_geoid,
    zone_component_id = component_id,
    zone_component_label = paste0("Zone ", LETTERS[zone_component_id])
  ) %>%
  arrange(zone_component_id, tract_geoid)

component_summary <- zone_components %>%
  count(zone_component_id, zone_component_label, name = "tract_count") %>%
  arrange(zone_component_id)

save_artifact(
  adjacency_edges,
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_adjacency_edges.rds"
)
save_artifact(
  zone_components,
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_zone_components.rds"
)
save_artifact(
  component_summary,
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_component_summary.rds"
)

message(glue::glue(
  "Section 04 build step 3 complete: {nrow(component_summary)} connected components across {nrow(zone_components)} tracts."
))

# Step 4: Generate zone geometries and deterministic labels
zone_component_metrics <- eligible_zone_inputs %>%
  sf::st_drop_geometry() %>%
  inner_join(zone_components, by = "tract_geoid") %>%
  group_by(zone_component_id) %>%
  summarise(
    tract_count = dplyr::n(),
    mean_tract_score = mean(tract_score, na.rm = TRUE),
    .groups = "drop"
  )

# Dissolve tracts into zone polygons
zones_raw <- eligible_zone_inputs %>%
  inner_join(zone_components, by = "tract_geoid") %>%
  group_by(zone_component_id) %>%
  summarise(.groups = "drop") %>%
  sf::st_make_valid()

# Deterministic ordering: score desc, then component id
zone_order <- zone_component_metrics %>%
  arrange(desc(mean_tract_score), zone_component_id) %>%
  mutate(
    zone_order = row_number(),
    zone_id = paste0("zone_", sprintf("%02d", zone_order)),
    zone_label = paste0("Zone ", LETTERS[zone_order])
  ) %>%
  select(zone_component_id, zone_order, zone_id, zone_label, tract_count, mean_tract_score)

zones <- zones_raw %>%
  left_join(zone_order, by = "zone_component_id")

# Geometry attributes in projected CRS for area calculations
zones_proj <- sf::st_transform(zones, 3086) # NAD83 / Florida GDL Albers
zone_area_sq_m <- as.numeric(sf::st_area(zones_proj))
zone_area_sq_mi <- zone_area_sq_m / 2589988.110336

# Label points in lon/lat for map annotation
label_points <- sf::st_point_on_surface(zones)
label_coords <- sf::st_coordinates(label_points)

zones <- zones %>%
  mutate(
    zone_area_sq_mi = zone_area_sq_mi,
    label_lon = label_coords[, "X"],
    label_lat = label_coords[, "Y"]
  ) %>%
  arrange(zone_order)

save_artifact(
  zones,
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_zones.rds"
)

save_artifact(
  zone_order,
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_zone_labels.rds"
)

message(glue::glue(
  "Section 04 build step 4 complete: {nrow(zones)} zone geometries generated."
))

# Step 5: Build zone summary metrics
zone_metric_base <- eligible_zone_inputs %>%
  sf::st_drop_geometry() %>%
  inner_join(zone_components, by = "tract_geoid")

safe_wmean <- function(x, w) {
  if (all(is.na(x))) return(NA_real_)
  w <- ifelse(is.na(w), 0, w)
  if (sum(w, na.rm = TRUE) == 0) {
    return(mean(x, na.rm = TRUE))
  }
  stats::weighted.mean(x, w, na.rm = TRUE)
}

zone_summary <- zone_metric_base %>%
  group_by(zone_component_id) %>%
  summarise(
    tracts = dplyr::n(),
    total_population = sum(pop_total, na.rm = TRUE),
    pop_growth_3yr_wtd = safe_wmean(pop_growth_3yr, pop_total),
    pop_density_median = median(pop_density, na.rm = TRUE),
    units_per_1k_3yr_wtd = safe_wmean(units_per_1k_3yr, pop_total),
    price_proxy_pctl_median = median(price_proxy_pctl, na.rm = TRUE),
    mean_tract_score = mean(tract_score, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(
    sf::st_drop_geometry(zones) %>%
      select(zone_component_id, zone_id, zone_label, zone_order, zone_area_sq_mi),
    by = "zone_component_id"
  ) %>%
  arrange(zone_order) %>%
  mutate(
    pop_growth_3yr_wtd_fmt = scales::percent(pop_growth_3yr_wtd, accuracy = 0.1),
    units_per_1k_3yr_wtd_fmt = scales::number(units_per_1k_3yr_wtd, accuracy = 0.1),
    price_proxy_pctl_median_fmt = scales::percent(price_proxy_pctl_median, accuracy = 0.1),
    pop_density_median_fmt = scales::comma(pop_density_median, accuracy = 1),
    total_population_fmt = scales::comma(total_population, accuracy = 1)
  ) %>%
  select(
    zone_id, zone_label, zone_order, zone_component_id,
    tracts, total_population, total_population_fmt,
    pop_growth_3yr_wtd, pop_growth_3yr_wtd_fmt,
    pop_density_median, pop_density_median_fmt,
    units_per_1k_3yr_wtd, units_per_1k_3yr_wtd_fmt,
    price_proxy_pctl_median, price_proxy_pctl_median_fmt,
    mean_tract_score, zone_area_sq_mi
  )

save_artifact(
  zone_summary,
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_zone_summary.rds"
)

message(glue::glue(
  "Section 04 build step 5 complete: zone summary generated for {nrow(zone_summary)} zones."
))
