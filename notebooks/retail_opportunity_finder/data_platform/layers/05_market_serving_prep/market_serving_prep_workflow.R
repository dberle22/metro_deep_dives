source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

platform_helpers_path <- "notebooks/retail_opportunity_finder/data_platform/shared/platform_helpers.R"
if (!file.exists(platform_helpers_path)) {
  stop("Missing data platform helper file.", call. = FALSE)
}
source(platform_helpers_path)

make_validation_row <- function(check_name, severity = "error", dataset = NA_character_, metric_value = NA_real_, pass = FALSE, details = NA_character_) {
  tibble::tibble(
    check_name = check_name,
    severity = severity,
    dataset = dataset,
    metric_value = metric_value,
    pass = pass,
    details = details
  )
}

safe_numeric <- function(x) suppressWarnings(as.numeric(x))

normalize_block_geoid <- function(x) {
  out <- gsub("[^0-9]", "", as.character(x))
  out[out == ""] <- NA_character_
  out
}

derive_tract_geoid_from_block <- function(x) {
  block_geoid <- normalize_block_geoid(x)
  ifelse(!is.na(block_geoid) & nchar(block_geoid) == 15, substr(block_geoid, 1, 11), NA_character_)
}

safe_percent_rank <- function(x) {
  if (length(x) == 0 || all(is.na(x))) return(rep(0.5, length(x)))
  out <- dplyr::percent_rank(x)
  out[is.na(out)] <- 0.5
  out
}

winsorize_vector <- function(x, lower_q = 0.05, upper_q = 0.95) {
  if (length(x) == 0 || all(is.na(x))) return(x)
  bounds <- stats::quantile(x, probs = c(lower_q, upper_q), na.rm = TRUE, names = FALSE)
  pmax(pmin(x, bounds[2]), bounds[1])
}

normalize_for_spatial_ops <- function(sf_obj, object_name, target_epsg = GEOMETRY_ASSUMPTIONS$analysis_crs_epsg) {
  if (!inherits(sf_obj, "sf")) {
    stop(glue::glue("{object_name} is not an sf object."), call. = FALSE)
  }
  sf_obj <- suppressWarnings(sf::st_make_valid(sf_obj))
  source_epsg <- sf::st_crs(sf_obj)$epsg
  if (is.na(source_epsg)) {
    stop(glue::glue("{object_name} has undefined CRS and cannot be transformed."), call. = FALSE)
  }
  if (identical(source_epsg, target_epsg)) {
    return(sf_obj)
  }
  sf::st_transform(sf_obj, target_epsg)
}

read_market_retail_parcels <- function(con, profile = get_market_profile()) {
  market_key_sql <- DBI::dbQuoteString(con, profile$market_key)
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT * FROM parcel.retail_parcels ",
      "WHERE market_key = ", market_key_sql, " ",
      "AND retail_flag = TRUE ",
      "ORDER BY county_geoid, parcel_uid"
    )
  ) %>%
    as_tibble() %>%
    mutate(
      census_block_id = as.character(census_block_id),
      county_code = as.character(county_code),
      county_fips = as.character(county_fips),
      county_geoid = as.character(county_geoid),
      parcel_uid = as.character(parcel_uid),
      parcel_id = as.character(parcel_id),
      join_key = as.character(join_key),
      land_use_code = as.character(land_use_code),
      retail_flag = as.logical(retail_flag),
      last_sale_date = as.Date(last_sale_date)
    )
}

read_market_parcel_join_qa <- function(con, profile = get_market_profile()) {
  market_key_sql <- DBI::dbQuoteString(con, profile$market_key)
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT * FROM parcel.parcel_join_qa ",
      "WHERE market_key = ", market_key_sql, " ",
      "ORDER BY county_geoid"
    )
  ) %>%
    as_tibble()
}

read_market_tract_geometry <- function(con, profile = get_market_profile()) {
  cbsa_code_sql <- DBI::dbQuoteString(con, profile$cbsa_code)
  tract_tbl <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT * FROM foundation.market_tract_geometry ",
      "WHERE cbsa_code = ", cbsa_code_sql, " ",
      "ORDER BY tract_geoid"
    )
  )

  if (nrow(tract_tbl) == 0) {
    stop("Missing foundation.market_tract_geometry rows for market.", call. = FALSE)
  }

  geometry_wkt_table_to_sf(tract_tbl, crs = GEOMETRY_ASSUMPTIONS$expected_crs_epsg)
}

read_market_zone_assignments <- function(con, profile = get_market_profile()) {
  market_key_sql <- DBI::dbQuoteString(con, profile$market_key)

  contiguity_assignments <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT c.tract_geoid, s.zone_id, s.zone_label, s.zone_order, s.mean_tract_score ",
      "FROM zones.contiguity_zone_components c ",
      "LEFT JOIN zones.contiguity_zone_summary s ",
      "ON c.market_key = s.market_key AND c.zone_component_id = s.zone_component_id ",
      "WHERE c.market_key = ", market_key_sql
    )
  ) %>%
    as_tibble() %>%
    mutate(zone_system = "contiguity")

  cluster_assignments <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT a.tract_geoid, a.cluster_id AS zone_id, a.cluster_label AS zone_label, ",
      "a.cluster_order AS zone_order, s.mean_tract_score ",
      "FROM zones.cluster_assignments a ",
      "LEFT JOIN zones.cluster_zone_summary s ",
      "ON a.market_key = s.market_key AND a.cluster_id = s.cluster_id ",
      "WHERE a.market_key = ", market_key_sql
    )
  ) %>%
    as_tibble() %>%
    mutate(zone_system = "cluster")

  dplyr::bind_rows(contiguity_assignments, cluster_assignments) %>%
    mutate(
      tract_geoid = as.character(tract_geoid),
      zone_id = as.character(zone_id),
      zone_label = as.character(zone_label)
    ) %>%
    select(zone_system, tract_geoid, zone_id, zone_label, zone_order, mean_tract_score)
}

read_market_zone_summaries <- function(con, profile = get_market_profile()) {
  market_key_sql <- DBI::dbQuoteString(con, profile$market_key)

  contiguity_summary <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT zone_id, zone_label, zone_order, tracts, total_population, ",
      "pop_growth_3yr_wtd, pop_density_median, units_per_1k_3yr_wtd, ",
      "price_proxy_pctl_median, mean_tract_score, zone_area_sq_mi ",
      "FROM zones.contiguity_zone_summary ",
      "WHERE market_key = ", market_key_sql
    )
  ) %>%
    as_tibble() %>%
    mutate(zone_system = "contiguity")

  cluster_summary <- DBI::dbGetQuery(
    con,
    paste0(
      "SELECT cluster_id AS zone_id, cluster_label AS zone_label, cluster_order AS zone_order, ",
      "tracts, total_population, pop_growth_3yr_wtd, pop_density_median, ",
      "units_per_1k_3yr_wtd, price_proxy_pctl_median, mean_tract_score, zone_area_sq_mi ",
      "FROM zones.cluster_zone_summary ",
      "WHERE market_key = ", market_key_sql
    )
  ) %>%
    as_tibble() %>%
    mutate(zone_system = "cluster")

  dplyr::bind_rows(contiguity_summary, cluster_summary) %>%
    mutate(
      zone_id = as.character(zone_id),
      zone_label = as.character(zone_label),
      zone_quality_score = safe_percent_rank(mean_tract_score)
    )
}

read_market_parcel_geometry_lookup <- function(parcel_join_qa, parcel_root = resolve_parcel_standardized_root()) {
  county_tags <- unique(stats::na.omit(parcel_join_qa$source_county_tag))
  geometry_paths <- file.path(parcel_root, "county_outputs", county_tags, "parcel_geometries_analysis.rds")
  geometry_paths <- geometry_paths[file.exists(geometry_paths)]

  if (length(geometry_paths) == 0) {
    stop("No parcel geometry analysis files found for market counties.", call. = FALSE)
  }

  parcel_county_list <- lapply(geometry_paths, function(path) {
    sf_obj <- readRDS(path)
    sf_obj$source_county_tag <- basename(dirname(path))
    sf_obj
  })

  dplyr::bind_rows(parcel_county_list) %>%
    mutate(
      join_key = trimws(as.character(join_key)),
      county = as.character(county),
      parcel_uid = paste0(county, "::", join_key),
      source_county_tag = if ("county_tag" %in% names(.)) {
        dplyr::coalesce(as.character(source_county_tag), as.character(county_tag))
      } else {
        as.character(source_county_tag)
      }
    ) %>%
    select(parcel_uid, source_county_tag, geometry) %>%
    filter(!is.na(parcel_uid), parcel_uid != "NA::NA") %>%
    distinct(parcel_uid, .keep_all = TRUE)
}

build_retail_parcels_with_geometry <- function(retail_parcels, geometry_lookup) {
  retail_sf <- retail_parcels %>%
    left_join(geometry_lookup, by = "parcel_uid") %>%
    sf::st_as_sf(sf_column_name = "geometry", crs = GEOMETRY_ASSUMPTIONS$expected_crs_epsg)
  has_geometry <- !is.na(sf::st_is_empty(retail_sf)) & !sf::st_is_empty(retail_sf)
  parcel_area_sqmi_from_geom <- rep(NA_real_, nrow(retail_sf))
  if (any(has_geometry)) {
    retail_sf_proj <- normalize_for_spatial_ops(retail_sf[has_geometry, ], "retail_parcels_with_geometry")
    parcel_area_sqmi_from_geom[has_geometry] <- as.numeric(sf::st_area(retail_sf_proj)) / 2589988.110336
  }
  parcel_area_sqft_source <- if ("parcel_area_sqft" %in% names(retail_sf)) safe_numeric(retail_sf$parcel_area_sqft) else rep(NA_real_, nrow(retail_sf))

  retail_sf %>%
    mutate(
      county = as.character(county_code),
      use_code_definition = as.character(land_use_description),
      use_code_type = as.character(land_use_category),
      parcel_area_sqmi = dplyr::coalesce(parcel_area_sqft_source / 27878400, parcel_area_sqmi_from_geom),
      assessed_value = dplyr::coalesce(safe_numeric(total_value), safe_numeric(land_value)),
      last_sale_price = safe_numeric(last_sale_price),
      last_sale_date = as.Date(last_sale_date)
    )
}

build_retail_parcel_tract_assignment <- function(retail_parcels_sf, tract_sf, profile = get_market_profile()) {
  retail_attrs <- retail_parcels_sf %>%
    mutate(
      census_block_id = as.character(census_block_id),
      tract_geoid_from_block = derive_tract_geoid_from_block(census_block_id)
    )

  tract_valid <- tract_sf %>%
    sf::st_drop_geometry() %>%
    transmute(tract_geoid = as.character(tract_geoid))

  assigned_from_block <- retail_attrs %>%
    sf::st_drop_geometry() %>%
    left_join(
      tract_valid %>% mutate(tract_exists = TRUE),
      by = c("tract_geoid_from_block" = "tract_geoid")
    ) %>%
    mutate(
      tract_exists = dplyr::coalesce(tract_exists, FALSE),
      tract_geoid = dplyr::if_else(tract_exists, tract_geoid_from_block, NA_character_),
      assignment_method = dplyr::if_else(!is.na(tract_geoid), "census_block_prefix", NA_character_),
      assignment_status = dplyr::if_else(!is.na(tract_geoid), "assigned", "needs_geometry_fallback")
    ) %>%
    select(parcel_uid, tract_geoid, assignment_method, assignment_status)

  fallback_ids <- assigned_from_block %>%
    filter(assignment_status == "needs_geometry_fallback") %>%
    pull(parcel_uid)

  fallback_assigned <- tibble::tibble(
    parcel_uid = character(),
    tract_geoid = character(),
    assignment_method = character(),
    assignment_status = character()
  )

  if (length(fallback_ids) > 0) {
    retail_fallback <- retail_parcels_sf %>%
      filter(parcel_uid %in% fallback_ids, !sf::st_is_empty(geometry))

    if (nrow(retail_fallback) > 0) {
      tract_sf_proj <- normalize_for_spatial_ops(tract_sf, "tract_sf")
      retail_parcels_proj <- normalize_for_spatial_ops(retail_fallback, "retail_parcels_sf")

      retail_point_geom <- sf::st_point_on_surface(sf::st_geometry(retail_parcels_proj))
      retail_points <- sf::st_as_sf(
        sf::st_drop_geometry(retail_parcels_proj),
        geometry = retail_point_geom,
        crs = GEOMETRY_ASSUMPTIONS$analysis_crs_epsg
      )

      fallback_assigned <- sf::st_join(
        retail_points,
        tract_sf_proj %>% select(tract_geoid),
        join = sf::st_within,
        left = TRUE
      ) %>%
        sf::st_drop_geometry() %>%
        transmute(
          parcel_uid,
          tract_geoid = as.character(tract_geoid),
          assignment_method = dplyr::if_else(!is.na(tract_geoid), "point_on_surface_within_tract", "point_on_surface_within_tract"),
          assignment_status = dplyr::if_else(!is.na(tract_geoid), "assigned", "unassigned")
        )
    }
  }

  retail_attrs %>%
    sf::st_drop_geometry() %>%
    left_join(assigned_from_block, by = "parcel_uid") %>%
    select(-assignment_method, -assignment_status, -tract_geoid) %>%
    left_join(fallback_assigned, by = "parcel_uid") %>%
    left_join(
      assigned_from_block %>%
        transmute(
          parcel_uid,
          tract_geoid_block = tract_geoid,
          assignment_method_block = assignment_method,
          assignment_status_block = assignment_status
        ),
      by = "parcel_uid"
    ) %>%
    mutate(
      tract_geoid = dplyr::coalesce(tract_geoid_block, tract_geoid),
      assignment_method = dplyr::coalesce(assignment_method_block, assignment_method, "unassigned"),
      assignment_status = dplyr::case_when(
        !is.na(tract_geoid_block) ~ "assigned",
        !is.na(tract_geoid) ~ "assigned",
        TRUE ~ "unassigned"
      )
    ) %>%
    transmute(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      state_abbr,
      state_fips,
      county_fips,
      county_geoid,
      county_code,
      county_tag,
      county_name,
      parcel_uid,
      parcel_id,
      join_key,
      land_use_code,
      retail_subtype,
      parcel_area_sqmi,
      just_value,
      land_value,
      impro_value,
      total_value,
      assessed_value,
      last_sale_date,
      last_sale_price,
      tract_geoid = as.character(tract_geoid),
      assignment_method,
      assignment_status,
      build_source = "data_platform/layers/05_market_serving_prep",
      run_timestamp = as.character(Sys.time())
    )
}

build_retail_intensity_by_tract <- function(parcel_assignment, tract_sf, profile = get_market_profile()) {
  tract_sf_area <- normalize_for_spatial_ops(tract_sf, "tract_sf_for_area")
  tract_area_sqmi <- as.numeric(sf::st_area(tract_sf_area)) / 2589988.110336
  tract_land_area <- tract_sf_area %>%
    sf::st_drop_geometry() %>%
    transmute(
      tract_geoid,
      county_geoid,
      tract_land_area_sqmi = tract_area_sqmi
    )

  retail_intensity <- parcel_assignment %>%
    filter(assignment_status == "assigned", !is.na(tract_geoid)) %>%
    group_by(tract_geoid) %>%
    summarise(
      retail_parcel_count = dplyr::n_distinct(parcel_uid),
      retail_area = sum(parcel_area_sqmi, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    right_join(tract_land_area, by = "tract_geoid") %>%
    mutate(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      retail_parcel_count = dplyr::coalesce(retail_parcel_count, 0L),
      retail_area = dplyr::coalesce(retail_area, 0),
      retail_area_density = dplyr::if_else(
        !is.na(tract_land_area_sqmi) & tract_land_area_sqmi > 0,
        retail_area / tract_land_area_sqmi,
        NA_real_
      ),
      pctl_tract_retail_parcel_count = safe_percent_rank(retail_parcel_count),
      pctl_tract_retail_area_density = safe_percent_rank(retail_area_density),
      local_retail_context_score = 0.5 * pctl_tract_retail_parcel_count + 0.5 * pctl_tract_retail_area_density,
      build_source = "data_platform/layers/05_market_serving_prep",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      county_geoid,
      tract_geoid,
      tract_land_area_sqmi,
      retail_parcel_count,
      retail_area,
      retail_area_density,
      pctl_tract_retail_parcel_count,
      pctl_tract_retail_area_density,
      local_retail_context_score,
      build_source,
      run_timestamp
    ) %>%
    arrange(tract_geoid)

  retail_intensity
}

build_parcel_zone_overlay <- function(zone_assignments, zone_summaries, retail_intensity_by_tract, profile = get_market_profile()) {
  zone_assignments %>%
    left_join(
      retail_intensity_by_tract %>%
        select(tract_geoid, retail_parcel_count, retail_area, tract_land_area_sqmi, local_retail_context_score),
      by = "tract_geoid"
    ) %>%
    group_by(zone_system, zone_id, zone_label, zone_order) %>%
    summarise(
      tracts = dplyr::n_distinct(tract_geoid),
      retail_parcel_count = sum(retail_parcel_count, na.rm = TRUE),
      retail_area = sum(retail_area, na.rm = TRUE),
      tract_land_area_sqmi = sum(tract_land_area_sqmi, na.rm = TRUE),
      retail_area_density = dplyr::if_else(tract_land_area_sqmi > 0, retail_area / tract_land_area_sqmi, NA_real_),
      local_retail_context_score = mean(local_retail_context_score, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    left_join(
      zone_summaries %>%
        select(zone_system, zone_id, mean_tract_score, zone_quality_score, zone_area_sq_mi, total_population),
      by = c("zone_system", "zone_id")
    ) %>%
    mutate(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      build_source = "data_platform/layers/05_market_serving_prep",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      zone_system,
      zone_id,
      zone_label,
      zone_order,
      tracts,
      total_population,
      zone_area_sq_mi,
      retail_parcel_count,
      retail_area,
      tract_land_area_sqmi,
      retail_area_density,
      local_retail_context_score,
      mean_tract_score,
      zone_quality_score,
      build_source,
      run_timestamp
    ) %>%
    arrange(zone_system, zone_order)
}

build_parcel_shortlist <- function(parcel_assignment, retail_parcels_sf, retail_intensity_by_tract, zone_assignments, zone_summaries, profile = get_market_profile()) {
  retail_attrs <- retail_parcels_sf %>%
    sf::st_drop_geometry() %>%
    select(
      parcel_uid,
      parcel_id,
      county,
      county_name,
      county_geoid,
      county_fips,
      state_abbr,
      state_fips,
      land_use_code,
      use_code_definition,
      use_code_type,
      owner_name,
      owner_addr,
      site_addr,
      retail_subtype,
      review_note,
      parcel_area_sqmi,
      just_value,
      assessed_value,
      last_sale_date,
      last_sale_price
    )

  parcel_shortlist_candidates <- parcel_assignment %>%
    filter(assignment_status == "assigned", !is.na(tract_geoid)) %>%
    select(parcel_uid, tract_geoid) %>%
    inner_join(zone_assignments, by = "tract_geoid", relationship = "many-to-many") %>%
    left_join(retail_attrs, by = "parcel_uid") %>%
    left_join(
      retail_intensity_by_tract %>%
        select(tract_geoid, pctl_tract_retail_parcel_count, pctl_tract_retail_area_density, local_retail_context_score),
      by = "tract_geoid"
    ) %>%
    left_join(
      zone_summaries %>%
        select(zone_system, zone_id, zone_quality_score),
      by = c("zone_system", "zone_id")
    )

  parcel_shortlist_candidates %>%
    mutate(
      model_id = "rof_v1",
      model_version = "locked_defaults_upstream_sprint7",
      min_area_sqft_for_value = 1000,
      just_value_clean = dplyr::if_else(!is.na(just_value) & just_value > 0, just_value, NA_real_),
      assessed_value_clean = dplyr::if_else(!is.na(assessed_value) & assessed_value > 0, assessed_value, NA_real_),
      parcel_area_sqft_est = parcel_area_sqmi * 27878400,
      parcel_area_sqft_clean = dplyr::if_else(
        !is.na(parcel_area_sqft_est) & parcel_area_sqft_est >= min_area_sqft_for_value,
        parcel_area_sqft_est,
        NA_real_
      ),
      assessed_value_psf = dplyr::if_else(
        !is.na(just_value_clean) & !is.na(parcel_area_sqft_clean) & parcel_area_sqft_clean > 0,
        just_value_clean / parcel_area_sqft_clean,
        NA_real_
      ),
      assessed_value_psf_winsorized = winsorize_vector(assessed_value_psf, lower_q = 0.05, upper_q = 0.95),
      sale_recency_days = as.numeric(difftime(Sys.Date(), last_sale_date, units = "days")),
      pctl_parcel_area = safe_percent_rank(parcel_area_sqmi),
      pctl_assessed_value_psf = safe_percent_rank(assessed_value_psf_winsorized),
      inv_pctl_assessed_value_psf = 1 - pctl_assessed_value_psf,
      pctl_sale_recency = safe_percent_rank(-sale_recency_days),
      parcel_characteristics_score = 0.4 * pctl_parcel_area + 0.3 * inv_pctl_assessed_value_psf + 0.3 * pctl_sale_recency,
      shortlist_score = 0.50 * zone_quality_score + 0.25 * local_retail_context_score + 0.25 * parcel_characteristics_score
    ) %>%
    arrange(zone_system, desc(shortlist_score), desc(zone_quality_score), desc(parcel_area_sqmi), parcel_uid) %>%
    group_by(zone_system) %>%
    mutate(shortlist_rank_system = row_number()) %>%
    ungroup() %>%
    group_by(zone_system, zone_id) %>%
    arrange(desc(shortlist_score), desc(parcel_area_sqmi), parcel_uid, .by_group = TRUE) %>%
    mutate(shortlist_rank_zone = row_number()) %>%
    ungroup() %>%
    mutate(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      build_source = "data_platform/layers/05_market_serving_prep",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      model_id,
      model_version,
      zone_system,
      zone_id,
      zone_label,
      shortlist_rank_system,
      shortlist_rank_zone,
      parcel_uid,
      parcel_id,
      tract_geoid,
      county_geoid,
      county_fips,
      county_name,
      state_abbr,
      land_use_code,
      use_code_definition,
      use_code_type,
      retail_subtype,
      review_note,
      owner_name,
      owner_addr,
      site_addr,
      parcel_area_sqmi,
      just_value,
      assessed_value,
      last_sale_date,
      last_sale_price,
      pctl_tract_retail_parcel_count,
      pctl_tract_retail_area_density,
      local_retail_context_score,
      mean_tract_score,
      zone_quality_score,
      parcel_characteristics_score,
      shortlist_score,
      build_source,
      run_timestamp
    )
}

build_parcel_shortlist_summary <- function(parcel_shortlist, profile = get_market_profile()) {
  parcel_shortlist %>%
    group_by(zone_system, zone_id, zone_label) %>%
    summarise(
      shortlisted_parcels = dplyr::n_distinct(parcel_uid),
      top_shortlist_score = max(shortlist_score, na.rm = TRUE),
      mean_shortlist_score = mean(shortlist_score, na.rm = TRUE),
      median_parcel_area_sqmi = median(parcel_area_sqmi, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      market_key = profile$market_key,
      cbsa_code = profile$cbsa_code,
      build_source = "data_platform/layers/05_market_serving_prep",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      zone_system,
      zone_id,
      zone_label,
      shortlisted_parcels,
      top_shortlist_score,
      mean_shortlist_score,
      median_parcel_area_sqmi,
      build_source,
      run_timestamp
    ) %>%
    arrange(zone_system, zone_id)
}

build_market_serving_qa <- function(products) {
  assignment_unassigned <- sum(products$retail_parcel_tract_assignment$assignment_status != "assigned", na.rm = TRUE)
  missing_geometry <- sum(is.na(sf::st_geometry(products$retail_parcels_sf)))
  intensity_dupes <- nrow(products$retail_intensity_by_tract) - dplyr::n_distinct(products$retail_intensity_by_tract$tract_geoid)
  overlay_dupes <- nrow(products$parcel_zone_overlay) - dplyr::n_distinct(paste(products$parcel_zone_overlay$zone_system, products$parcel_zone_overlay$zone_id, sep = "::"))
  shortlist_dupes <- if (!is.null(products$parcel_shortlist) && nrow(products$parcel_shortlist) > 0) {
    nrow(products$parcel_shortlist) - dplyr::n_distinct(paste(products$parcel_shortlist$zone_system, products$parcel_shortlist$parcel_uid, sep = "::"))
  } else {
    0L
  }
  shortlist_missing_score <- if (!is.null(products$parcel_shortlist) && nrow(products$parcel_shortlist) > 0 && "shortlist_score" %in% names(products$parcel_shortlist)) {
    sum(is.na(products$parcel_shortlist$shortlist_score), na.rm = TRUE)
  } else {
    0L
  }

  dplyr::bind_rows(
    make_validation_row(
      "serving_retail_parcel_missing_geometry",
      dataset = "serving.retail_parcel_tract_assignment",
      metric_value = missing_geometry,
      pass = missing_geometry == 0,
      details = paste("Retail parcels without geometry after .RDS join:", missing_geometry)
    ),
    make_validation_row(
      "serving_tract_assignment_unassigned_parcels",
      severity = "warning",
      dataset = "serving.retail_parcel_tract_assignment",
      metric_value = assignment_unassigned,
      pass = assignment_unassigned == 0,
      details = paste("Retail parcels without tract assignment:", assignment_unassigned)
    ),
    make_validation_row(
      "serving_retail_intensity_unique_tract",
      dataset = "serving.retail_intensity_by_tract",
      metric_value = intensity_dupes,
      pass = intensity_dupes == 0,
      details = paste("Duplicate tract rows in retail intensity:", intensity_dupes)
    ),
    make_validation_row(
      "serving_zone_overlay_unique_zone",
      dataset = "serving.parcel_zone_overlay",
      metric_value = overlay_dupes,
      pass = overlay_dupes == 0,
      details = paste("Duplicate zone rows in parcel zone overlay:", overlay_dupes)
    ),
    make_validation_row(
      "serving_shortlist_unique_zone_parcel",
      dataset = "serving.parcel_shortlist",
      metric_value = shortlist_dupes,
      pass = shortlist_dupes == 0,
      details = paste("Duplicate zone-system parcel rows in shortlist:", shortlist_dupes)
    ),
    make_validation_row(
      "serving_shortlist_missing_scores",
      severity = "warning",
      dataset = "serving.parcel_shortlist",
      metric_value = shortlist_missing_score,
      pass = shortlist_missing_score == 0,
      details = paste("Shortlist rows with missing shortlist_score:", shortlist_missing_score)
    )
  ) %>%
    mutate(
      build_source = "data_platform/layers/05_market_serving_prep",
      run_timestamp = as.character(Sys.time())
    )
}

build_market_serving_products <- function(con, profile = get_market_profile(), parcel_root = resolve_parcel_standardized_root()) {
  retail_parcels <- read_market_retail_parcels(con, profile = profile)
  parcel_join_qa <- read_market_parcel_join_qa(con, profile = profile)
  tract_sf <- read_market_tract_geometry(con, profile = profile)
  zone_assignments <- read_market_zone_assignments(con, profile = profile)
  zone_summaries <- read_market_zone_summaries(con, profile = profile)
  geometry_lookup <- read_market_parcel_geometry_lookup(parcel_join_qa, parcel_root = parcel_root)
  retail_parcels_sf <- build_retail_parcels_with_geometry(retail_parcels, geometry_lookup)
  retail_parcel_tract_assignment <- build_retail_parcel_tract_assignment(retail_parcels_sf, tract_sf, profile = profile)
  retail_intensity_by_tract <- build_retail_intensity_by_tract(retail_parcel_tract_assignment, tract_sf, profile = profile)
  parcel_zone_overlay <- build_parcel_zone_overlay(zone_assignments, zone_summaries, retail_intensity_by_tract, profile = profile)
  parcel_shortlist <- build_parcel_shortlist(
    retail_parcel_tract_assignment,
    retail_parcels_sf,
    retail_intensity_by_tract,
    zone_assignments,
    zone_summaries,
    profile = profile
  )
  parcel_shortlist_summary <- build_parcel_shortlist_summary(parcel_shortlist, profile = profile)

  products <- list(
    retail_parcels_sf = retail_parcels_sf,
    retail_parcel_tract_assignment = retail_parcel_tract_assignment,
    retail_intensity_by_tract = retail_intensity_by_tract,
    parcel_zone_overlay = parcel_zone_overlay,
    parcel_shortlist = parcel_shortlist,
    parcel_shortlist_summary = parcel_shortlist_summary
  )

  products$qa_validation_results <- build_market_serving_qa(products)
  products
}

publish_market_serving_products <- function(con, products) {
  ensure_rof_duckdb_schemas(con)

  write_duckdb_table(con, "serving", "retail_parcel_tract_assignment", products$retail_parcel_tract_assignment, overwrite = TRUE)
  write_duckdb_table(con, "serving", "retail_intensity_by_tract", products$retail_intensity_by_tract, overwrite = TRUE)
  write_duckdb_table(con, "serving", "parcel_zone_overlay", products$parcel_zone_overlay, overwrite = TRUE)
  write_duckdb_table(con, "serving", "parcel_shortlist", products$parcel_shortlist, overwrite = TRUE)
  write_duckdb_table(con, "serving", "parcel_shortlist_summary", products$parcel_shortlist_summary, overwrite = TRUE)
  write_duckdb_table(con, "qa", "market_serving_validation_results", products$qa_validation_results, overwrite = TRUE)

  list(
    retail_parcel_tract_assignment = nrow(products$retail_parcel_tract_assignment),
    retail_intensity_by_tract = nrow(products$retail_intensity_by_tract),
    parcel_zone_overlay = nrow(products$parcel_zone_overlay),
    parcel_shortlist = nrow(products$parcel_shortlist),
    parcel_shortlist_summary = nrow(products$parcel_shortlist_summary),
    qa_validation_results = nrow(products$qa_validation_results)
  )
}
