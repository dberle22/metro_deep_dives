suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
  library(glue)
  library(sf)
  library(stringr)
})

split_schema_table <- function(table_name) {
  parts <- strsplit(table_name, ".", fixed = TRUE)[[1]]
  if (length(parts) != 2) {
    stop(glue("Expected schema-qualified table name, got: {table_name}"), call. = FALSE)
  }

  list(schema = parts[[1]], table = parts[[2]])
}

assert_duckdb_tables <- function(con, table_names) {
  missing <- table_names[!vapply(table_names, function(table_name) {
    parts <- split_schema_table(table_name)
    duckdb_table_exists(con, parts$schema, parts$table)
  }, logical(1))]

  if (length(missing) > 0) {
    stop(
      glue(
        "Notebook build requires prebuilt DuckDB tables. Missing: {paste(missing, collapse = ', ')}"
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

read_duckdb_query <- function(con, sql, object_name = "query result") {
  out <- DBI::dbGetQuery(con, sql)
  if (is.null(out)) {
    stop(glue("Failed to load {object_name}."), call. = FALSE)
  }
  out
}

drop_platform_metadata <- function(df) {
  df %>%
    select(-any_of(c("market_key", "state_scope", "build_source", "run_timestamp")))
}

read_market_table <- function(
    con,
    table_name,
    profile = get_market_profile(),
    select_sql = "*",
    apply_default_filter = TRUE,
    where_sql = NULL,
    order_sql = NULL) {
  parts <- split_schema_table(table_name)
  clauses <- c(glue("SELECT {select_sql} FROM {table_name}"))

  if (isTRUE(duckdb_table_exists(con, parts$schema, parts$table))) {
    query <- paste(clauses, collapse = " ")
  } else {
    stop(glue("Missing required table: {table_name}"), call. = FALSE)
  }

  default_where <- if (!isTRUE(apply_default_filter)) {
    NULL
  } else if (parts$schema %in% c("foundation")) {
    glue("cbsa_code = '{profile$cbsa_code}'")
  } else if (parts$schema %in% c("ref")) {
    NULL
  } else {
    glue("market_key = '{profile$market_key}'")
  }

  where_clause <- paste(c(default_where, where_sql), collapse = " AND ")
  where_clause <- where_clause[nzchar(where_clause)]

  if (length(where_clause) > 0) {
    query <- paste(query, "WHERE", where_clause)
  }

  if (!is.null(order_sql) && nzchar(order_sql)) {
    query <- paste(query, "ORDER BY", order_sql)
  }

  read_duckdb_query(con, query, object_name = table_name)
}

read_market_sf_table <- function(
    con,
    table_name,
    profile = get_market_profile(),
    apply_default_filter = TRUE,
    where_sql = NULL,
    order_sql = NULL,
    crs = GEOMETRY_ASSUMPTIONS$expected_crs_epsg) {
  tbl <- read_market_table(
    con = con,
    table_name = table_name,
    profile = profile,
    apply_default_filter = apply_default_filter,
    where_sql = where_sql,
    order_sql = order_sql
  )

  geometry_wkt_table_to_sf(tbl, crs = crs)
}

build_default_cluster_params <- function() {
  list(
    method = "distance_connected_components",
    eps_meters = 6000,
    min_pts = 2,
    noise_policy = "nearest_core",
    projected_epsg = 3086
  )
}

build_contiguity_adjacency_edges <- function(zone_inputs) {
  candidate_sf <- zone_inputs %>% arrange(tract_geoid)
  neighbor_idx <- sf::st_touches(candidate_sf)
  n <- nrow(candidate_sf)

  edge_tbl <- lapply(seq_len(n), function(i) {
    nbrs <- neighbor_idx[[i]]
    if (length(nbrs) == 0) {
      return(NULL)
    }

    nbrs <- nbrs[nbrs > i]
    if (length(nbrs) == 0) {
      return(NULL)
    }

    data.frame(
      from_idx = rep(i, length(nbrs)),
      to_idx = nbrs,
      stringsAsFactors = FALSE
    )
  }) %>%
    dplyr::bind_rows()

  if (nrow(edge_tbl) == 0) {
    return(data.frame(
      from_tract_geoid = character(),
      to_tract_geoid = character(),
      stringsAsFactors = FALSE
    ))
  }

  edge_tbl %>%
    mutate(
      from_tract_geoid = candidate_sf$tract_geoid[from_idx],
      to_tract_geoid = candidate_sf$tract_geoid[to_idx]
    ) %>%
    select(from_tract_geoid, to_tract_geoid)
}

safe_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

safe_percent_rank <- function(x) {
  if (length(x) == 0) {
    return(numeric())
  }
  if (all(is.na(x))) {
    return(rep(0.5, length(x)))
  }
  out <- dplyr::percent_rank(x)
  out[is.na(out)] <- 0.5
  out
}

winsorize_vector <- function(x, lower_q = 0.05, upper_q = 0.95) {
  if (length(x) == 0 || all(is.na(x))) {
    return(x)
  }

  bounds <- stats::quantile(x, probs = c(lower_q, upper_q), na.rm = TRUE, names = FALSE)
  pmax(pmin(x, bounds[2]), bounds[1])
}

enrich_shortlist_metrics <- function(df) {
  df %>%
    mutate(
      just_value_clean = dplyr::if_else(!is.na(just_value) & just_value > 0, just_value, NA_real_),
      assessed_value_clean = dplyr::if_else(!is.na(assessed_value) & assessed_value > 0, assessed_value, NA_real_),
      parcel_area_sqft_est = parcel_area_sqmi * 27878400,
      parcel_area_sqft_clean = dplyr::if_else(
        !is.na(parcel_area_sqft_est) & parcel_area_sqft_est >= 1000,
        parcel_area_sqft_est,
        NA_real_
      ),
      assessed_value_psf = dplyr::if_else(
        !is.na(just_value_clean) & !is.na(parcel_area_sqft_clean) & parcel_area_sqft_clean > 0,
        just_value_clean / parcel_area_sqft_clean,
        NA_real_
      ),
      assessed_value_psf_winsorized = winsorize_vector(assessed_value_psf, lower_q = 0.05, upper_q = 0.95),
      pctl_assessed_value_psf = safe_percent_rank(assessed_value_psf_winsorized),
      inv_pctl_assessed_value_psf = 1 - pctl_assessed_value_psf
    )
}

validate_sf_light <- function(
    sf_obj,
    name,
    expected_epsg = GEOMETRY_ASSUMPTIONS$expected_crs_epsg,
    validity_sample_n = 5000L,
    require_no_empty = TRUE) {
  is_sf <- inherits(sf_obj, "sf")
  n <- if (is_sf) nrow(sf_obj) else NA_integer_
  crs <- if (is_sf) sf::st_crs(sf_obj)$epsg else NA_integer_
  n_empty <- if (is_sf) sum(sf::st_is_empty(sf_obj)) else NA_integer_

  sample_n <- if (is_sf) min(validity_sample_n, n) else 0L
  invalid_sample <- NA_integer_
  if (is_sf && sample_n > 0) {
    idx <- seq_len(sample_n)
    valid_sample <- sf::st_is_valid(sf_obj[idx, ])
    invalid_sample <- sum(!valid_sample, na.rm = TRUE)
  }

  list(
    dataset = name,
    is_sf = is_sf,
    n_rows = n,
    crs_epsg = crs,
    empty_geometries = n_empty,
    validity_sample_n = sample_n,
    invalid_geometries_sample = invalid_sample,
    pass = is_sf &&
      !is.na(n) && n > 0 &&
      !is.na(crs) && crs == expected_epsg &&
      !is.na(n_empty) && (!isTRUE(require_no_empty) || n_empty == 0)
  )
}

build_geometry_lookup <- function(parcel_root, parcel_join_qa, expected_epsg = GEOMETRY_ASSUMPTIONS$expected_crs_epsg) {
  parcel_geometry_paths <- resolve_parcel_analysis_paths(parcel_root)
  market_geometry_tags <- if (!is.null(parcel_join_qa) &&
    nrow(parcel_join_qa) > 0 &&
    "source_county_tag" %in% names(parcel_join_qa)) {
    unique(stats::na.omit(parcel_join_qa$source_county_tag))
  } else {
    character()
  }

  if (length(market_geometry_tags) > 0) {
    parcel_geometry_paths <- parcel_geometry_paths[basename(dirname(parcel_geometry_paths)) %in% market_geometry_tags]
  }

  if (length(parcel_geometry_paths) == 0) {
    stop(
      glue("No county parcel geometry files found under {parcel_root}/county_outputs/*/parcel_geometries_analysis.rds"),
      call. = FALSE
    )
  }

  parcel_county_list <- lapply(parcel_geometry_paths, function(path) {
    sf_obj <- readRDS(path)
    if (!inherits(sf_obj, "sf")) {
      stop(glue("Expected sf parcel geometry object at {path}."), call. = FALSE)
    }
    if (is.na(sf::st_crs(sf_obj))) {
      stop(glue("Parcel geometry object is missing CRS metadata: {path}"), call. = FALSE)
    }
    # County parcel geometry files are not consistently stored in the same CRS.
    # Normalize them before row-binding so Jacksonville and other multi-county
    # markets do not fail with "arguments have different crs".
    if (sf::st_crs(sf_obj)$epsg != expected_epsg || is.na(sf::st_crs(sf_obj)$epsg)) {
      sf_obj <- sf::st_transform(sf_obj, expected_epsg)
    }
    # Some county parcel geometry files still contain invalid polygon topology
    # after CRS normalization (for example self-intersections / duplicate edges).
    # Repair them here so downstream parcel attach can proceed.
    sf_obj <- sf::st_make_valid(sf_obj)
    sf_obj$source_county_tag <- basename(dirname(path))
    sf_obj
  })

  parcels_raw <- dplyr::bind_rows(parcel_county_list)
  parcel_required_cols <- c(
    "join_key", "parcel_id", "county", "county_name", "use_code",
    "land_value", "total_value", "sale_price1", "sale_yr1", "sale_mo1",
    "qa_missing_join_key", "qa_zero_county", "geometry"
  )

  parcel_schema_check <- validate_columns(
    parcels_raw,
    parcel_required_cols,
    "parcel_geometries_analysis_combined"
  )
  parcel_geom_check <- validate_sf_light(
    parcels_raw,
    "parcel_geometries_analysis_combined",
    expected_epsg,
    require_no_empty = FALSE
  )

  geometry_lookup <- parcels_raw %>%
    mutate(
      join_key = trimws(as.character(join_key)),
      county = as.character(county),
      parcel_uid = paste0(county, "::", join_key),
      source_county_tag = dplyr::coalesce(
        as.character(source_county_tag),
        if ("county_tag" %in% names(parcels_raw)) as.character(.data$county_tag) else NA_character_
      )
    ) %>%
    select(parcel_uid, source_county_tag, geometry) %>%
    filter(!is.na(parcel_uid), !stringr::str_detect(parcel_uid, "^NA::"), parcel_uid != "NA::NA") %>%
    distinct(parcel_uid, .keep_all = TRUE)

  list(
    parcel_geometry_paths = parcel_geometry_paths,
    parcels_raw = parcels_raw,
    parcel_schema_check = parcel_schema_check,
    parcel_geom_check = parcel_geom_check,
    geometry_lookup = geometry_lookup
  )
}

attach_geometry <- function(df, geometry_lookup, dataset_name, crs_epsg = GEOMETRY_ASSUMPTIONS$expected_crs_epsg) {
  sf_obj <- df %>%
    left_join(geometry_lookup, by = "parcel_uid") %>%
    sf::st_as_sf(sf_column_name = "geometry", crs = crs_epsg)

  geom_check <- validate_sf_light(
    sf_obj,
    dataset_name,
    crs_epsg,
    require_no_empty = FALSE
  )

  list(
    data = sf_obj,
    geometry_check = geom_check,
    missing_geometry = sum(is.na(sf::st_dimension(sf_obj$geometry)))
  )
}
