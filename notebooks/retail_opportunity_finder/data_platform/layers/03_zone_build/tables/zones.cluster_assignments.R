build_cluster_zone_products <- function(eligible_zone_inputs, cluster_params = list(
  method = "distance_connected_components",
  eps_meters = 6000,
  min_pts = 2,
  noise_policy = "nearest_core",
  projected_epsg = 3086
)) {
  zone_inputs_proj <- sf::st_transform(eligible_zone_inputs, cluster_params$projected_epsg)
  centroids_proj <- sf::st_centroid(zone_inputs_proj)
  coords <- sf::st_coordinates(centroids_proj)

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

  is_small_component <- assignment_tbl$component_size < cluster_params$min_pts
  cluster_raw_id <- assignment_tbl$raw_component_id

  if (any(is_small_component)) {
    core_components <- assignment_tbl %>%
      filter(component_size >= cluster_params$min_pts) %>%
      distinct(raw_component_id)

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
      max_id <- max(cluster_raw_id, na.rm = TRUE)
      small_idx <- which(is_small_component)
      cluster_raw_id[small_idx] <- max_id + seq_along(small_idx)
    }
  }

  assignment_tbl <- assignment_tbl %>%
    mutate(cluster_raw_id = as.integer(cluster_raw_id))

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

  cluster_zones <- eligible_zone_inputs %>%
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

  cluster_zone_summary <- eligible_zone_inputs %>%
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

  list(
    cluster_assignments = cluster_assignments,
    cluster_zones = cluster_zones,
    cluster_zone_summary = cluster_zone_summary,
    cluster_params = cluster_params
  )
}
