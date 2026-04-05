source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

platform_helpers_path <- "notebooks/retail_opportunity_finder/data_platform/shared/platform_helpers.R"
if (!file.exists(platform_helpers_path)) {
  stop("Missing data platform helper file.", call. = FALSE)
}
source(platform_helpers_path)

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

publish_zone_build_products <- function(
    con,
    zone_inputs,
    contiguity_products,
    cluster_products,
    profile = get_market_profile(),
    build_source = "data_platform/layers/03_zone_build") {
  ensure_rof_duckdb_schemas(con)

  write_duckdb_table(
    con,
    "zones",
    "zone_input_candidates",
    prepend_market_metadata(
      sf_to_geometry_wkt_table(zone_inputs %>% select(tract_geoid, eligible_v1, tract_score, tract_rank, zone_candidate)),
      profile = profile,
      build_source = build_source
    ),
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "contiguity_zone_components",
    prepend_market_metadata(contiguity_products$zone_components, profile = profile, build_source = build_source) %>%
      mutate(zone_method = "contiguity"),
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "contiguity_zone_summary",
    prepend_market_metadata(contiguity_products$zone_summary, profile = profile, build_source = build_source) %>%
      mutate(zone_method = "contiguity"),
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "contiguity_zone_geometries",
    prepend_market_metadata(
      sf_to_geometry_wkt_table(contiguity_products$zones),
      profile = profile,
      build_source = build_source
    ) %>%
      mutate(zone_method = "contiguity"),
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "cluster_assignments",
    prepend_market_metadata(cluster_products$cluster_assignments, profile = profile, build_source = build_source) %>%
      mutate(zone_method = "cluster"),
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "cluster_zone_summary",
    prepend_market_metadata(cluster_products$cluster_zone_summary, profile = profile, build_source = build_source) %>%
      mutate(zone_method = "cluster"),
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "cluster_zone_geometries",
    prepend_market_metadata(
      sf_to_geometry_wkt_table(cluster_products$cluster_zones),
      profile = profile,
      build_source = build_source
    ) %>%
      mutate(zone_method = "cluster"),
    overwrite = TRUE
  )

  invisible(
    list(
      zone_input_candidates = nrow(zone_inputs),
      contiguity_zones = nrow(contiguity_products$zone_summary),
      cluster_zones = nrow(cluster_products$cluster_zone_summary)
    )
  )
}
