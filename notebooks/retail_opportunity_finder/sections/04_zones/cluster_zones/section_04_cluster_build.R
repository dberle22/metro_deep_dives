# Section 04 cluster build script
# Purpose: generate cluster-based zones from eligible tract candidates.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 04 cluster build")

zone_inputs <- readRDS(read_artifact_path("04_zones", "section_04_zone_input_candidates"))

cluster_params <- list(
  method = "distance_connected_components",
  eps_meters = 6000,          # TUNE: distance radius (meters). Larger => fewer, bigger clusters.
  min_pts = 2,                # TUNE: minimum size to be treated as a core component.
  noise_policy = "nearest_core", # TUNE: "singleton" (many small clusters) vs "nearest_core" (fewer clusters).
  projected_epsg = 3086
)

safe_wmean <- function(x, w) {
  if (all(is.na(x))) return(NA_real_)
  w <- ifelse(is.na(w), 0, w)
  if (sum(w, na.rm = TRUE) == 0) return(mean(x, na.rm = TRUE))
  stats::weighted.mean(x, w, na.rm = TRUE)
}

index_to_letters <- function(i) {
  out <- character(length(i))
  for (k in seq_along(i)) {
    n <- i[k]
    s <- ""
    while (n > 0) {
      rem <- (n - 1) %% 26
      s <- paste0(LETTERS[rem + 1], s)
      n <- (n - 1) %/% 26
    }
    out[k] <- s
  }
  out
}

connected_components <- function(neighbor_list) {
  n <- length(neighbor_list)
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
      nbrs <- neighbor_list[[node]]
      if (length(nbrs) == 0) next
      unassigned <- nbrs[is.na(component_id[nbrs])]
      if (length(unassigned) > 0) {
        component_id[unassigned] <- current_component
        queue <- c(queue, unassigned)
      }
    }
  }

  component_id
}

# 1) Compute centroid coordinates in projected CRS
zone_inputs_proj <- sf::st_transform(zone_inputs, cluster_params$projected_epsg)
centroids_proj <- sf::st_centroid(zone_inputs_proj)
coords <- sf::st_coordinates(centroids_proj)

# 2) Create proximity graph using distance threshold
neighbors <- sf::st_is_within_distance(centroids_proj, dist = cluster_params$eps_meters)
raw_component_id <- connected_components(neighbors)

component_sizes <- as.data.frame(table(raw_component_id), stringsAsFactors = FALSE) %>%
  mutate(
    raw_component_id = as.integer(raw_component_id),
    component_size = as.integer(Freq)
  ) %>%
  select(raw_component_id, component_size)

assignment_tbl <- zone_inputs_proj %>%
  sf::st_drop_geometry() %>%
  transmute(
    tract_geoid,
    tract_score,
    pop_total,
    pop_growth_3yr,
    pop_density,
    units_per_1k_3yr,
    price_proxy_pctl,
    centroid_x = coords[, "X"],
    centroid_y = coords[, "Y"],
    raw_component_id = raw_component_id
  ) %>%
  left_join(component_sizes, by = "raw_component_id")

# 3) Apply min_pts + noise policy
is_small_component <- assignment_tbl$component_size < cluster_params$min_pts
cluster_raw_id <- assignment_tbl$raw_component_id

if (any(is_small_component)) {
  core_components <- assignment_tbl %>%
    filter(component_size >= cluster_params$min_pts) %>%
    distinct(raw_component_id)

  # TUNE BEHAVIOR: switch noise policy in cluster_params above.
  # - nearest_core: assign small/noise tracts to nearest core cluster centroid.
  # - singleton: split each small/noise tract into its own cluster.
  if (cluster_params$noise_policy == "nearest_core" && nrow(core_components) > 0) {
    core_centroids <- assignment_tbl %>%
      filter(raw_component_id %in% core_components$raw_component_id) %>%
      group_by(raw_component_id) %>%
      summarise(
        cx = mean(centroid_x, na.rm = TRUE),
        cy = mean(centroid_y, na.rm = TRUE),
        .groups = "drop"
      )

    small_idx <- which(is_small_component)
    for (i in small_idx) {
      dx <- core_centroids$cx - assignment_tbl$centroid_x[i]
      dy <- core_centroids$cy - assignment_tbl$centroid_y[i]
      nearest <- which.min(dx^2 + dy^2)
      cluster_raw_id[i] <- core_centroids$raw_component_id[nearest]
    }
  } else {
    # singleton policy: each small-component tract gets its own cluster
    max_id <- max(cluster_raw_id, na.rm = TRUE)
    small_idx <- which(is_small_component)
    cluster_raw_id[small_idx] <- max_id + seq_along(small_idx)
  }
}

assignment_tbl <- assignment_tbl %>%
  mutate(
    cluster_raw_id = as.integer(cluster_raw_id)
  )

# 4) Deterministic cluster labels
cluster_order_tbl <- assignment_tbl %>%
  group_by(cluster_raw_id) %>%
  summarise(
    tracts = dplyr::n(),
    mean_tract_score = mean(tract_score, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(mean_tract_score), cluster_raw_id) %>%
  mutate(
    cluster_order = row_number(),
    cluster_id = paste0("cluster_", sprintf("%02d", cluster_order)),
    cluster_label = paste0("Cluster Zone ", index_to_letters(cluster_order))
  ) %>%
  select(cluster_raw_id, cluster_order, cluster_id, cluster_label, tracts, mean_tract_score)

cluster_assignments <- assignment_tbl %>%
  left_join(cluster_order_tbl, by = "cluster_raw_id") %>%
  select(
    tract_geoid,
    cluster_raw_id,
    cluster_id,
    cluster_label,
    cluster_order,
    tracts,
    tract_score,
    pop_total,
    pop_growth_3yr,
    pop_density,
    units_per_1k_3yr,
    price_proxy_pctl
  )

# 5) Dissolve polygons into cluster zones
cluster_zones <- zone_inputs %>%
  inner_join(
    cluster_assignments %>% select(tract_geoid, cluster_id, cluster_label, cluster_order, cluster_raw_id),
    by = "tract_geoid"
  ) %>%
  group_by(cluster_id, cluster_label, cluster_order, cluster_raw_id) %>%
  summarise(.groups = "drop") %>%
  sf::st_make_valid()

cluster_zones_proj <- sf::st_transform(cluster_zones, cluster_params$projected_epsg)
cluster_area_sq_mi <- as.numeric(sf::st_area(cluster_zones_proj)) / 2589988.110336

label_points_proj <- sf::st_point_on_surface(cluster_zones_proj)
label_points_ll <- sf::st_transform(label_points_proj, GEOMETRY_ASSUMPTIONS$expected_crs_epsg)
label_coords <- sf::st_coordinates(label_points_ll)

cluster_zones <- cluster_zones %>%
  mutate(
    zone_area_sq_mi = cluster_area_sq_mi,
    label_lon = label_coords[, "X"],
    label_lat = label_coords[, "Y"]
  ) %>%
  arrange(cluster_order)

# 6) Cluster zone summary
cluster_zone_summary <- zone_inputs %>%
  sf::st_drop_geometry() %>%
  inner_join(cluster_assignments %>% select(tract_geoid, cluster_id, cluster_label, cluster_order), by = "tract_geoid") %>%
  group_by(cluster_id, cluster_label, cluster_order) %>%
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
    cluster_zones %>%
      sf::st_drop_geometry() %>%
      select(cluster_id, zone_area_sq_mi),
    by = "cluster_id"
  ) %>%
  arrange(cluster_order)

save_artifact(
  cluster_assignments,
  resolve_output_path("04_zones", "section_04_cluster_assignments")
)
save_artifact(
  cluster_zones,
  resolve_output_path("04_zones", "section_04_cluster_zones")
)
save_artifact(
  cluster_zone_summary,
  resolve_output_path("04_zones", "section_04_cluster_zone_summary")
)
save_artifact(
  cluster_params,
  resolve_output_path("04_zones", "section_04_cluster_params")
)

message(glue::glue(
  "Cluster build complete: {nrow(cluster_zone_summary)} cluster zones generated from {nrow(cluster_assignments)} tracts."
))
