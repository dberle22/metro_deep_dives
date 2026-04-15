build_contiguity_zone_products <- function(eligible_zone_inputs) {
  candidate_sf <- eligible_zone_inputs %>% arrange(tract_geoid)
  neighbor_idx <- sf::st_touches(candidate_sf)
  n <- nrow(candidate_sf)

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

  component_id <- connected_components(neighbor_idx)

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

  zone_component_metrics <- eligible_zone_inputs %>%
    sf::st_drop_geometry() %>%
    inner_join(zone_components, by = "tract_geoid") %>%
    group_by(zone_component_id) %>%
    summarise(
      tract_count = dplyr::n(),
      mean_tract_score = mean(tract_score, na.rm = TRUE),
      .groups = "drop"
    )

  zones_raw <- eligible_zone_inputs %>%
    inner_join(zone_components, by = "tract_geoid") %>%
    group_by(zone_component_id) %>%
    summarise(.groups = "drop") %>%
    sf::st_make_valid()

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

  zones_proj <- sf::st_transform(zones, 3086)
  zone_area_sq_mi <- as.numeric(sf::st_area(zones_proj)) / 2589988.110336

  label_points <- sf::st_point_on_surface(zones)
  label_coords <- sf::st_coordinates(label_points)

  zones <- zones %>%
    mutate(
      zone_area_sq_mi = zone_area_sq_mi,
      label_lon = label_coords[, "X"],
      label_lat = label_coords[, "Y"]
    ) %>%
    arrange(zone_order)

  zone_summary <- eligible_zone_inputs %>%
    sf::st_drop_geometry() %>%
    inner_join(zone_components, by = "tract_geoid") %>%
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

  list(
    adjacency_edges = adjacency_edges,
    zone_components = zone_components,
    component_summary = component_summary,
    zone_labels = zone_order,
    zones = zones,
    zone_summary = zone_summary
  )
}
