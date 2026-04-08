source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

platform_helpers_path <- "notebooks/retail_opportunity_finder/data_platform/shared/platform_helpers.R"
if (!file.exists(platform_helpers_path)) {
  stop("Missing data platform helper file.", call. = FALSE)
}
source(platform_helpers_path)

# Source individual table builders
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.retail_parcel_tract_assignment.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.retail_intensity_by_tract.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.parcel_zone_overlay.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.parcel_shortlist.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.parcel_shortlist_summary.R")
source("notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/qa.market_serving_validation_results.R")

MARKET_SERVING_LAYER_ROOT <- "notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep"
MARKET_SERVING_TABLE_ROOT <- file.path(MARKET_SERVING_LAYER_ROOT, "tables")

resolve_market_serving_table_asset <- function(table_name, extension = "sql") {
  path <- file.path(MARKET_SERVING_TABLE_ROOT, paste0(table_name, ".", extension))
  if (!file.exists(path)) {
    stop(sprintf("Market serving table asset not found: %s", path), call. = FALSE)
  }
  path
}

render_market_serving_sql <- function(path, replacements = list()) {
  sql <- read_sql_file(path)
  if (length(replacements) > 0) {
    for (name in names(replacements)) {
      placeholder <- paste0("{{", name, "}}")
      sql <- gsub(placeholder, replacements[[name]], sql, fixed = TRUE)
    }
  }
  sql
}

query_market_serving_sql <- function(con, table_name, replacements = list()) {
  sql_path <- resolve_market_serving_table_asset(table_name, "sql")
  sql <- render_market_serving_sql(sql_path, replacements = replacements)
  DBI::dbGetQuery(con, sql)
}

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

read_market_retail_parcels <- function(con, profile) {
  market_key_sql <- DBI::dbQuoteString(con, profile$market_key)
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT * FROM parcel.parcels_canonical ",
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

read_market_parcel_join_qa <- function(con, profile) {
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

read_market_tract_geometry <- function(con, profile) {
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

read_market_zone_assignments <- function(con, profile) {
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

read_market_zone_summaries <- function(con, profile) {
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

# Multi-market processing function
build_market_serving_layer_publications <- function(con, profiles) {
  all_retail_parcel_tract_assignment <- list()
  all_retail_intensity_by_tract <- list()
  all_parcel_zone_overlay <- list()
  all_parcel_shortlist <- list()
  all_parcel_shortlist_summary <- list()
  all_qa_validation_results <- list()

  for (i in 1:nrow(profiles)) {
    profile <- profiles[i, ]
    message(glue::glue("Processing market serving for {profile$market_key} ({profile$cbsa_code})"))

    # Read market-specific inputs
    retail_parcels <- read_market_retail_parcels(con, profile)
    parcel_join_qa <- read_market_parcel_join_qa(con, profile)
    tract_sf <- read_market_tract_geometry(con, profile)
    zone_assignments <- read_market_zone_assignments(con, profile)
    zone_summaries <- read_market_zone_summaries(con, profile)
    geometry_lookup <- read_market_parcel_geometry_lookup(parcel_join_qa)
    retail_parcels_sf <- build_retail_parcels_with_geometry(retail_parcels, geometry_lookup)

    # Build tables using individual builders
    retail_parcel_tract_assignment <- build_retail_parcel_tract_assignment(con, retail_parcels_sf, profile)
    retail_intensity_by_tract <- build_retail_intensity_by_tract(con, retail_parcel_tract_assignment, tract_sf, profile)
    parcel_zone_overlay <- build_parcel_zone_overlay(con, zone_assignments, zone_summaries, retail_intensity_by_tract, profile)
    parcel_shortlist <- build_parcel_shortlist(con, retail_parcel_tract_assignment, retail_intensity_by_tract, profile)
    parcel_shortlist_summary <- build_parcel_shortlist_summary(con, parcel_shortlist, profile)

    # Build QA for this market
    products <- list(
      retail_parcels_sf = retail_parcels_sf,
      retail_parcel_tract_assignment = retail_parcel_tract_assignment,
      retail_intensity_by_tract = retail_intensity_by_tract,
      parcel_zone_overlay = parcel_zone_overlay,
      parcel_shortlist = parcel_shortlist,
      parcel_shortlist_summary = parcel_shortlist_summary
    )
    qa_validation_results <- build_market_serving_qa(products, profile)

    # Accumulate results
    all_retail_parcel_tract_assignment <- c(all_retail_parcel_tract_assignment, list(retail_parcel_tract_assignment))
    all_retail_intensity_by_tract <- c(all_retail_intensity_by_tract, list(retail_intensity_by_tract))
    all_parcel_zone_overlay <- c(all_parcel_zone_overlay, list(parcel_zone_overlay))
    all_parcel_shortlist <- c(all_parcel_shortlist, list(parcel_shortlist))
    all_parcel_shortlist_summary <- c(all_parcel_shortlist_summary, list(parcel_shortlist_summary))
    all_qa_validation_results <- c(all_qa_validation_results, list(qa_validation_results))
  }

  # Combine all markets
  list(
    retail_parcel_tract_assignment = dplyr::bind_rows(all_retail_parcel_tract_assignment),
    retail_intensity_by_tract = dplyr::bind_rows(all_retail_intensity_by_tract),
    parcel_zone_overlay = dplyr::bind_rows(all_parcel_zone_overlay),
    parcel_shortlist = dplyr::bind_rows(all_parcel_shortlist),
    parcel_shortlist_summary = dplyr::bind_rows(all_parcel_shortlist_summary),
    qa_validation_results = dplyr::bind_rows(all_qa_validation_results)
  )
}

# Legacy single-market function for backward compatibility
build_market_serving_products <- function(con, profile = get_market_profile(), parcel_root = resolve_parcel_standardized_root()) {
  retail_parcels <- read_market_retail_parcels(con, profile)
  parcel_join_qa <- read_market_parcel_join_qa(con, profile)
  tract_sf <- read_market_tract_geometry(con, profile)
  zone_assignments <- read_market_zone_assignments(con, profile)
  zone_summaries <- read_market_zone_summaries(con, profile)
  geometry_lookup <- read_market_parcel_geometry_lookup(parcel_join_qa, parcel_root = parcel_root)
  retail_parcels_sf <- build_retail_parcels_with_geometry(retail_parcels, geometry_lookup)
  retail_parcel_tract_assignment <- build_retail_parcel_tract_assignment(con, retail_parcels_sf, profile)
  retail_intensity_by_tract <- build_retail_intensity_by_tract(con, retail_parcel_tract_assignment, tract_sf, profile)
  parcel_zone_overlay <- build_parcel_zone_overlay(con, zone_assignments, zone_summaries, retail_intensity_by_tract, profile)
  parcel_shortlist <- build_parcel_shortlist(con, retail_parcel_tract_assignment, retail_intensity_by_tract, profile)
  parcel_shortlist_summary <- build_parcel_shortlist_summary(con, parcel_shortlist, profile)

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

read_market_retail_parcels <- function(con, profile = get_market_profile()) {
  market_key_sql <- DBI::dbQuoteString(con, profile$market_key)
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT * FROM parcel.parcels_canonical ",
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

build_retail_parcel_tract_assignment <- function(con, retail_parcels_sf, profile = get_market_profile()) {
  retail_parcels_wkt <- sf_to_geometry_wkt_table(retail_parcels_sf) %>%
    mutate(
      census_block_id = as.character(census_block_id),
      county_code = as.character(county_code),
      county_fips = as.character(county_fips),
      county_geoid = as.character(county_geoid),
      parcel_uid = as.character(parcel_uid),
      parcel_id = as.character(parcel_id),
      join_key = as.character(join_key),
      land_use_code = as.character(land_use_code),
      retail_subtype = as.character(retail_subtype),
      last_sale_date = as.Date(last_sale_date)
    )

  DBI::dbWriteTable(con, "tmp_retail_parcels_with_geometry", retail_parcels_wkt, temporary = TRUE, overwrite = TRUE)
  retail_parcel_tract_assignment <- query_market_serving_sql(
    con,
    "serving.retail_parcel_tract_assignment",
    list(retail_parcels_table = "tmp_retail_parcels_with_geometry")
  )

  retail_parcel_tract_assignment %>%
    mutate(
      build_source = "data_platform/layers/05_market_serving_prep/tables/serving.retail_parcel_tract_assignment.sql",
      run_timestamp = as.character(Sys.time())
    )
}

build_retail_intensity_by_tract <- function(con, parcel_assignment, tract_sf, profile = get_market_profile()) {
  DBI::dbWriteTable(con, "tmp_retail_parcel_tract_assignment", parcel_assignment, temporary = TRUE, overwrite = TRUE)
  retail_intensity <- query_market_serving_sql(
    con,
    "serving.retail_intensity_by_tract",
    list(parcel_assignment_table = "tmp_retail_parcel_tract_assignment")
  )

  retail_intensity %>%
    mutate(
      build_source = "data_platform/layers/05_market_serving_prep/tables/serving.retail_intensity_by_tract.sql",
      run_timestamp = as.character(Sys.time())
    )
}

build_parcel_zone_overlay <- function(con, zone_assignments, zone_summaries, retail_intensity_by_tract, profile = get_market_profile()) {
  DBI::dbWriteTable(con, "tmp_retail_intensity_by_tract", retail_intensity_by_tract, temporary = TRUE, overwrite = TRUE)
  parcel_zone_overlay <- query_market_serving_sql(
    con,
    "serving.parcel_zone_overlay",
    list(retail_intensity_by_tract_table = "tmp_retail_intensity_by_tract")
  )

  parcel_zone_overlay %>%
    mutate(
      build_source = "data_platform/layers/05_market_serving_prep/tables/serving.parcel_zone_overlay.sql",
      run_timestamp = as.character(Sys.time())
    )
}

build_parcel_shortlist <- function(con, parcel_assignment, retail_intensity_by_tract, profile = get_market_profile()) {
  DBI::dbWriteTable(con, "tmp_retail_parcel_tract_assignment", parcel_assignment, temporary = TRUE, overwrite = TRUE)
  DBI::dbWriteTable(con, "tmp_retail_intensity_by_tract", retail_intensity_by_tract, temporary = TRUE, overwrite = TRUE)

  parcel_shortlist <- query_market_serving_sql(
    con,
    "serving.parcel_shortlist",
    list(
      parcel_assignment_table = "tmp_retail_parcel_tract_assignment",
      retail_intensity_by_tract_table = "tmp_retail_intensity_by_tract"
    )
  )

  parcel_shortlist %>%
    mutate(
      build_source = "data_platform/layers/05_market_serving_prep/tables/serving.parcel_shortlist.sql",
      run_timestamp = as.character(Sys.time())
    )
}

build_parcel_shortlist_summary <- function(con, parcel_shortlist, profile = get_market_profile()) {
  DBI::dbWriteTable(con, "tmp_parcel_shortlist", parcel_shortlist, temporary = TRUE, overwrite = TRUE)
  parcel_shortlist_summary <- query_market_serving_sql(
    con,
    "serving.parcel_shortlist_summary",
    list(parcel_shortlist_table = "tmp_parcel_shortlist")
  )

  parcel_shortlist_summary %>%
    mutate(
      build_source = "data_platform/layers/05_market_serving_prep/tables/serving.parcel_shortlist_summary.sql",
      run_timestamp = as.character(Sys.time())
    )
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
  retail_parcel_tract_assignment <- build_retail_parcel_tract_assignment(con, retail_parcels_sf, profile = profile)
  retail_intensity_by_tract <- build_retail_intensity_by_tract(con, retail_parcel_tract_assignment, tract_sf, profile = profile)
  parcel_zone_overlay <- build_parcel_zone_overlay(con, zone_assignments, zone_summaries, retail_intensity_by_tract, profile = profile)
  parcel_shortlist <- build_parcel_shortlist(con, retail_parcel_tract_assignment, retail_intensity_by_tract, profile = profile)
  parcel_shortlist_summary <- build_parcel_shortlist_summary(con, parcel_shortlist, profile = profile)

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
