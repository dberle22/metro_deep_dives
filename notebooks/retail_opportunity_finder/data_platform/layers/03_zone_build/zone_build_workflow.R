source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

tract_scoring_workflow_path <- "notebooks/retail_opportunity_finder/data_platform/layers/02_tract_scoring/tract_scoring_workflow.R"
if (!exists("resolve_scoring_market_profiles")) {
  if (!file.exists(tract_scoring_workflow_path)) {
    stop("Missing tract scoring workflow file.", call. = FALSE)
  }
  source(tract_scoring_workflow_path)
}

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

ZONE_BUILD_LAYER_ROOT <- "notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build"
ZONE_BUILD_TABLE_ROOT <- file.path(ZONE_BUILD_LAYER_ROOT, "tables")
ZONE_BUILD_TARGET_STATES <- c("FL", "GA", "NC", "SC")

resolve_zone_build_table_asset <- function(table_name, extension) {
  path <- file.path(ZONE_BUILD_TABLE_ROOT, paste0(table_name, ".", extension))
  if (!file.exists(path)) {
    stop(sprintf("Zone build layer table asset not found: %s", path), call. = FALSE)
  }
  path
}

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

source(resolve_zone_build_table_asset("zones.zone_input_candidates", "R"))
source(resolve_zone_build_table_asset("zones.contiguity_zone_components", "R"))
source(resolve_zone_build_table_asset("zones.contiguity_zone_summary", "R"))
source(resolve_zone_build_table_asset("zones.contiguity_zone_geometries", "R"))
source(resolve_zone_build_table_asset("zones.cluster_assignments", "R"))
source(resolve_zone_build_table_asset("zones.cluster_zone_summary", "R"))
source(resolve_zone_build_table_asset("zones.cluster_zone_geometries", "R"))

read_zone_build_scoring_inputs <- function(con, profile) {
  if (!duckdb_table_exists(con, "scoring", "tract_scores")) {
    stop("Missing scoring.tract_scores; run Layer 02 before Layer 03.", call. = FALSE)
  }

  if (!duckdb_table_exists(con, "scoring", "cluster_seed_tracts")) {
    stop("Missing scoring.cluster_seed_tracts; run Layer 02 before Layer 03.", call. = FALSE)
  }

  if (!duckdb_table_exists(con, "foundation", "tract_features")) {
    stop("Missing foundation.tract_features; run Layer 01 before Layer 03.", call. = FALSE)
  }

  scored_tracts <- DBI::dbGetQuery(
    con,
    glue::glue(
      "SELECT * FROM scoring.tract_scores ",
      "WHERE market_key = '{profile$market_key}' AND cbsa_code = '{profile$cbsa_code}'"
    )
  ) %>%
    select(-any_of(c("market_key", "state_scope", "build_source", "run_timestamp")))

  tract_feature_context <- DBI::dbGetQuery(
    con,
    glue::glue(
      "SELECT cbsa_code, tract_geoid, pop_total ",
      "FROM foundation.tract_features ",
      "WHERE cbsa_code = '{profile$cbsa_code}'"
    )
  )

  scored_tracts <- scored_tracts %>%
    left_join(
      tract_feature_context %>% select(cbsa_code, tract_geoid, pop_total),
      by = c("cbsa_code", "tract_geoid")
    )

  cluster_seed_tracts <- DBI::dbGetQuery(
    con,
    glue::glue(
      "SELECT * FROM scoring.cluster_seed_tracts ",
      "WHERE market_key = '{profile$market_key}' AND cbsa_code = '{profile$cbsa_code}'"
    )
  ) %>%
    select(-any_of(c("market_key", "state_scope", "build_source", "run_timestamp")))

  if (nrow(scored_tracts) == 0) {
    stop(
      sprintf(
        "No scoring.tract_scores rows found for market '%s' (cbsa_code=%s).",
        profile$market_key,
        profile$cbsa_code
      ),
      call. = FALSE
    )
  }

  if (nrow(cluster_seed_tracts) == 0) {
    stop(
      sprintf(
        "No scoring.cluster_seed_tracts rows found for market '%s' (cbsa_code=%s).",
        profile$market_key,
        profile$cbsa_code
      ),
      call. = FALSE
    )
  }

  tract_wkb <- query_tract_geometry_wkb(con, profile = profile, cbsa_code = profile$cbsa_code)
  tract_sf <- sf_from_wkb_df(tract_wkb, c("tract_geoid")) %>%
    left_join(
      scored_tracts %>% select(tract_geoid, eligible_v1),
      by = "tract_geoid"
    )

  list(
    profile = profile,
    scored_tracts = scored_tracts,
    tract_component_scores = scored_tracts,
    cluster_seed_tracts = cluster_seed_tracts,
    tract_sf = tract_sf
  )
}

build_zone_build_market_products <- function(con, profile) {
  scoring_inputs <- read_zone_build_scoring_inputs(con, profile)

  zone_inputs_bundle <- build_zone_input_candidates(
    scoring_inputs$scored_tracts,
    scoring_inputs$tract_sf,
    scoring_inputs$tract_component_scores,
    scoring_inputs$cluster_seed_tracts
  )

  if (!isTRUE(zone_inputs_bundle$readiness_report$pass)) {
    stop(
      sprintf(
        "Zone input readiness checks failed for market '%s' (cbsa_code=%s).",
        profile$market_key,
        profile$cbsa_code
      ),
      call. = FALSE
    )
  }

  contiguity_products <- build_contiguity_zone_products(zone_inputs_bundle$eligible_zone_inputs)
  cluster_products <- build_cluster_zone_products(zone_inputs_bundle$eligible_zone_inputs)

  list(
    profile = profile,
    scoring_inputs = scoring_inputs,
    zone_inputs_bundle = zone_inputs_bundle,
    contiguity_products = contiguity_products,
    cluster_products = cluster_products
  )
}

assess_zone_build_market <- function(con, profile) {
  scoring_inputs <- read_zone_build_scoring_inputs(con, profile)

  zone_inputs_bundle <- build_zone_input_candidates(
    scoring_inputs$scored_tracts,
    scoring_inputs$tract_sf,
    scoring_inputs$tract_component_scores,
    scoring_inputs$cluster_seed_tracts
  )

  list(
    profile = profile,
    scoring_inputs = scoring_inputs,
    zone_inputs_bundle = zone_inputs_bundle,
    ready = isTRUE(zone_inputs_bundle$readiness_report$pass)
  )
}

build_zone_build_market_publication_tables <- function(
    zone_inputs,
    contiguity_products,
    cluster_products,
    profile = get_market_profile()) {
  build_sources <- list(
    zone_input_candidates = sub("^notebooks/retail_opportunity_finder/", "", resolve_zone_build_table_asset("zones.zone_input_candidates", "R")),
    contiguity_zone_components = sub("^notebooks/retail_opportunity_finder/", "", resolve_zone_build_table_asset("zones.contiguity_zone_components", "R")),
    contiguity_zone_summary = sub("^notebooks/retail_opportunity_finder/", "", resolve_zone_build_table_asset("zones.contiguity_zone_summary", "R")),
    contiguity_zone_geometries = sub("^notebooks/retail_opportunity_finder/", "", resolve_zone_build_table_asset("zones.contiguity_zone_geometries", "R")),
    cluster_assignments = sub("^notebooks/retail_opportunity_finder/", "", resolve_zone_build_table_asset("zones.cluster_assignments", "R")),
    cluster_zone_summary = sub("^notebooks/retail_opportunity_finder/", "", resolve_zone_build_table_asset("zones.cluster_zone_summary", "R")),
    cluster_zone_geometries = sub("^notebooks/retail_opportunity_finder/", "", resolve_zone_build_table_asset("zones.cluster_zone_geometries", "R"))
  )

  list(
    zone_input_candidates = prepend_market_metadata(
      sf_to_geometry_wkt_table(zone_inputs %>% select(tract_geoid, eligible_v1, tract_score, tract_rank, zone_candidate)),
      profile = profile,
      build_source = build_sources$zone_input_candidates
    ),
    contiguity_zone_components = prepend_market_metadata(
      contiguity_products$zone_components,
      profile = profile,
      build_source = build_sources$contiguity_zone_components
    ) %>%
      mutate(zone_method = "contiguity"),
    contiguity_zone_summary = prepend_market_metadata(
      build_contiguity_zone_summary_table(contiguity_products),
      profile = profile,
      build_source = build_sources$contiguity_zone_summary
    ) %>%
      mutate(zone_method = "contiguity"),
    contiguity_zone_geometries = prepend_market_metadata(
      sf_to_geometry_wkt_table(build_contiguity_zone_geometries_table(contiguity_products)),
      profile = profile,
      build_source = build_sources$contiguity_zone_geometries
    ) %>%
      mutate(zone_method = "contiguity"),
    cluster_assignments = prepend_market_metadata(
      cluster_products$cluster_assignments,
      profile = profile,
      build_source = build_sources$cluster_assignments
    ) %>%
      mutate(zone_method = "cluster"),
    cluster_zone_summary = prepend_market_metadata(
      build_cluster_zone_summary_table(cluster_products),
      profile = profile,
      build_source = build_sources$cluster_zone_summary
    ) %>%
      mutate(zone_method = "cluster"),
    cluster_zone_geometries = prepend_market_metadata(
      sf_to_geometry_wkt_table(build_cluster_zone_geometries_table(cluster_products)),
      profile = profile,
      build_source = build_sources$cluster_zone_geometries
    ) %>%
      mutate(zone_method = "cluster")
  )
}

publish_zone_build_products <- function(
    con,
    zone_inputs,
    contiguity_products,
    cluster_products,
    profile = get_market_profile()) {
  ensure_rof_duckdb_schemas(con)
  publication_tables <- build_zone_build_market_publication_tables(
    zone_inputs = zone_inputs,
    contiguity_products = contiguity_products,
    cluster_products = cluster_products,
    profile = profile
  )

  write_duckdb_table(
    con,
    "zones",
    "zone_input_candidates",
    publication_tables$zone_input_candidates,
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "contiguity_zone_components",
    publication_tables$contiguity_zone_components,
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "contiguity_zone_summary",
    publication_tables$contiguity_zone_summary,
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "contiguity_zone_geometries",
    publication_tables$contiguity_zone_geometries,
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "cluster_assignments",
    publication_tables$cluster_assignments,
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "cluster_zone_summary",
    publication_tables$cluster_zone_summary,
    overwrite = TRUE
  )

  write_duckdb_table(
    con,
    "zones",
    "cluster_zone_geometries",
    publication_tables$cluster_zone_geometries,
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

build_zone_build_layer_publications <- function(
    con,
    profiles = resolve_scoring_market_profiles(con, target_states = ZONE_BUILD_TARGET_STATES)) {
  per_market <- list()
  skipped_markets <- list()

  for (profile in profiles) {
    result <- tryCatch(
      {
        assessment <- assess_zone_build_market(con, profile)

        if (!isTRUE(assessment$ready)) {
          readiness <- assessment$zone_inputs_bundle$readiness_report
          skipped_tbl <- tibble::tibble(
            market_key = profile$market_key,
            cbsa_code = profile$cbsa_code,
            state_scope = format_state_scope(profile),
            scored_rows = readiness$counts$scored_rows,
            tract_sf_rows = readiness$counts$tract_sf_rows,
            cluster_seed_from_scored = readiness$counts$cluster_seed_from_scored,
            cluster_seed_from_geom = readiness$counts$cluster_seed_from_geom,
            missing_scored_in_geom = length(readiness$set_differences$missing_scored_in_geom),
            missing_geom_in_scored = length(readiness$set_differences$missing_geom_in_scored),
            missing_component_in_geom = length(readiness$set_differences$missing_component_in_geom),
            reason = sprintf(
              "Zone input readiness failed: %s scored cluster-seed tracts missing from tract geometry; %s geometry-only cluster-seed tracts missing from scored inputs; %s component cluster-seed tracts missing from tract geometry.",
              length(readiness$set_differences$missing_scored_in_geom),
              length(readiness$set_differences$missing_geom_in_scored),
              length(readiness$set_differences$missing_component_in_geom)
            )
          )

          list(kind = "skipped", skipped = skipped_tbl)
        } else {
          products <- list(
            profile = assessment$profile,
            scoring_inputs = assessment$scoring_inputs,
            zone_inputs_bundle = assessment$zone_inputs_bundle,
            contiguity_products = build_contiguity_zone_products(assessment$zone_inputs_bundle$eligible_zone_inputs),
            cluster_products = build_cluster_zone_products(assessment$zone_inputs_bundle$eligible_zone_inputs)
          )
          publication_tables <- build_zone_build_market_publication_tables(
            zone_inputs = products$zone_inputs_bundle$eligible_zone_inputs,
            contiguity_products = products$contiguity_products,
            cluster_products = products$cluster_products,
            profile = profile
          )

          list(
            kind = "success",
            value = list(
              profile = profile,
              publication_tables = publication_tables,
              summary = tibble::tibble(
                market_key = profile$market_key,
                cbsa_code = profile$cbsa_code,
                state_scope = format_state_scope(profile),
                zone_input_candidates = nrow(publication_tables$zone_input_candidates),
                contiguity_zone_components = nrow(publication_tables$contiguity_zone_components),
                contiguity_zone_summary = nrow(publication_tables$contiguity_zone_summary),
                contiguity_zone_geometries = nrow(publication_tables$contiguity_zone_geometries),
                cluster_assignments = nrow(publication_tables$cluster_assignments),
                cluster_zone_summary = nrow(publication_tables$cluster_zone_summary),
                cluster_zone_geometries = nrow(publication_tables$cluster_zone_geometries)
              )
            )
          )
        }
      },
      error = function(e) list(kind = "error", error = e)
    )

    if (identical(result$kind, "success")) {
      per_market[[length(per_market) + 1L]] <- result$value
    } else if (identical(result$kind, "skipped")) {
      skipped_markets[[length(skipped_markets) + 1L]] <- result$skipped
    } else {
      skipped_markets[[length(skipped_markets) + 1L]] <- tibble::tibble(
        market_key = profile$market_key,
        cbsa_code = profile$cbsa_code,
        state_scope = format_state_scope(profile),
        scored_rows = NA_integer_,
        tract_sf_rows = NA_integer_,
        cluster_seed_from_scored = NA_integer_,
        cluster_seed_from_geom = NA_integer_,
        missing_scored_in_geom = NA_integer_,
        missing_geom_in_scored = NA_integer_,
        missing_component_in_geom = NA_integer_,
        reason = conditionMessage(result$error)
      )
    }
  }

  if (length(per_market) == 0) {
    stop("No zone-build markets passed readiness checks.", call. = FALSE)
  }

  bind_named_tables <- function(table_name) {
    dplyr::bind_rows(lapply(per_market, function(x) x$publication_tables[[table_name]]))
  }

  list(
    profiles = profiles,
    zone_input_candidates = bind_named_tables("zone_input_candidates"),
    contiguity_zone_components = bind_named_tables("contiguity_zone_components"),
    contiguity_zone_summary = bind_named_tables("contiguity_zone_summary"),
    contiguity_zone_geometries = bind_named_tables("contiguity_zone_geometries"),
    cluster_assignments = bind_named_tables("cluster_assignments"),
    cluster_zone_summary = bind_named_tables("cluster_zone_summary"),
    cluster_zone_geometries = bind_named_tables("cluster_zone_geometries"),
    market_summary = dplyr::bind_rows(lapply(per_market, `[[`, "summary")),
    skipped_markets = if (length(skipped_markets) > 0) dplyr::bind_rows(skipped_markets) else tibble::tibble(
      market_key = character(),
      cbsa_code = character(),
      state_scope = character(),
      scored_rows = integer(),
      tract_sf_rows = integer(),
      cluster_seed_from_scored = integer(),
      cluster_seed_from_geom = integer(),
      missing_scored_in_geom = integer(),
      missing_geom_in_scored = integer(),
      missing_component_in_geom = integer(),
      reason = character()
    )
  )
}

build_zone_build_qa <- function(publications, qa_summary) {
  contiguity_row_match <- nrow(publications$contiguity_zone_summary) == nrow(publications$contiguity_zone_geometries)
  cluster_row_match <- nrow(publications$cluster_zone_summary) == nrow(publications$cluster_zone_geometries)
  zone_input_component_row_match <- nrow(publications$zone_input_candidates) == nrow(publications$contiguity_zone_components)
  zone_input_cluster_row_match <- nrow(publications$zone_input_candidates) == nrow(publications$cluster_assignments)

  contiguity_market_match <- dplyr::n_distinct(publications$contiguity_zone_summary$market_key) ==
    dplyr::n_distinct(publications$contiguity_zone_geometries$market_key)
  cluster_market_match <- dplyr::n_distinct(publications$cluster_zone_summary$market_key) ==
    dplyr::n_distinct(publications$cluster_zone_geometries$market_key)

  validation_results <- dplyr::bind_rows(
    make_validation_row(
      "zone_build_multi_market_present",
      dataset = "zones.zone_input_candidates",
      metric_value = qa_summary$published_market_count,
      pass = isTRUE(qa_summary$multi_market_present),
      details = paste("Published markets:", qa_summary$published_market_count)
    ),
    make_validation_row(
      "zone_build_target_states_present",
      dataset = "zones.zone_input_candidates",
      metric_value = length(unique(publications$zone_input_candidates$state_scope)),
      pass = isTRUE(qa_summary$target_states_present),
      details = paste("Published state scopes:", paste(sort(unique(publications$zone_input_candidates$state_scope)), collapse = ", "))
    ),
    make_validation_row(
      "zone_build_published_plus_skipped_matches_expected",
      dataset = "zones.zone_input_candidates",
      metric_value = qa_summary$published_market_count + qa_summary$skipped_market_count,
      pass = (qa_summary$published_market_count + qa_summary$skipped_market_count) == qa_summary$expected_market_count,
      details = paste("Published + skipped markets:", qa_summary$published_market_count + qa_summary$skipped_market_count, "Expected:", qa_summary$expected_market_count)
    ),
    make_validation_row(
      "zone_build_skipped_markets",
      severity = "warning",
      dataset = "qa.zone_build_skipped_markets",
      metric_value = qa_summary$skipped_market_count,
      pass = qa_summary$skipped_market_count == 0,
      details = if (qa_summary$skipped_market_count == 0) {
        "No skipped markets."
      } else {
        paste("Skipped markets:", paste(qa_summary$skipped_markets$market_key, collapse = ", "))
      }
    ),
    make_validation_row(
      "zone_input_candidates_unique_market_tract",
      dataset = "zones.zone_input_candidates",
      metric_value = qa_summary$zone_input_key_dupes,
      pass = qa_summary$zone_input_key_dupes == 0,
      details = paste("Duplicate (market_key, tract_geoid) rows:", qa_summary$zone_input_key_dupes)
    ),
    make_validation_row(
      "contiguity_zone_components_unique_market_tract",
      dataset = "zones.contiguity_zone_components",
      metric_value = qa_summary$contiguity_component_key_dupes,
      pass = qa_summary$contiguity_component_key_dupes == 0,
      details = paste("Duplicate (market_key, tract_geoid) rows:", qa_summary$contiguity_component_key_dupes)
    ),
    make_validation_row(
      "contiguity_zone_summary_unique_market_zone",
      dataset = "zones.contiguity_zone_summary",
      metric_value = qa_summary$contiguity_summary_key_dupes,
      pass = qa_summary$contiguity_summary_key_dupes == 0,
      details = paste("Duplicate (market_key, zone_id) rows:", qa_summary$contiguity_summary_key_dupes)
    ),
    make_validation_row(
      "contiguity_zone_geometries_unique_market_zone",
      dataset = "zones.contiguity_zone_geometries",
      metric_value = qa_summary$contiguity_geometry_key_dupes,
      pass = qa_summary$contiguity_geometry_key_dupes == 0,
      details = paste("Duplicate (market_key, zone_id) rows:", qa_summary$contiguity_geometry_key_dupes)
    ),
    make_validation_row(
      "cluster_assignments_unique_market_tract",
      dataset = "zones.cluster_assignments",
      metric_value = qa_summary$cluster_assignment_key_dupes,
      pass = qa_summary$cluster_assignment_key_dupes == 0,
      details = paste("Duplicate (market_key, tract_geoid) rows:", qa_summary$cluster_assignment_key_dupes)
    ),
    make_validation_row(
      "cluster_zone_summary_unique_market_cluster",
      dataset = "zones.cluster_zone_summary",
      metric_value = qa_summary$cluster_summary_key_dupes,
      pass = qa_summary$cluster_summary_key_dupes == 0,
      details = paste("Duplicate (market_key, cluster_id) rows:", qa_summary$cluster_summary_key_dupes)
    ),
    make_validation_row(
      "cluster_zone_geometries_unique_market_cluster",
      dataset = "zones.cluster_zone_geometries",
      metric_value = qa_summary$cluster_geometry_key_dupes,
      pass = qa_summary$cluster_geometry_key_dupes == 0,
      details = paste("Duplicate (market_key, cluster_id) rows:", qa_summary$cluster_geometry_key_dupes)
    ),
    make_validation_row(
      "zone_build_one_cbsa_per_market",
      dataset = "zones.zone_input_candidates",
      metric_value = sum(!qa_summary$one_cbsa_per_market),
      pass = isTRUE(qa_summary$one_cbsa_per_market),
      details = paste("One cbsa_code per market:", qa_summary$one_cbsa_per_market)
    ),
    make_validation_row(
      "zone_input_candidates_matches_contiguity_components_rows",
      dataset = "zones.zone_input_candidates,zones.contiguity_zone_components",
      metric_value = abs(nrow(publications$zone_input_candidates) - nrow(publications$contiguity_zone_components)),
      pass = zone_input_component_row_match,
      details = paste("Zone input rows:", nrow(publications$zone_input_candidates), "Contiguity component rows:", nrow(publications$contiguity_zone_components))
    ),
    make_validation_row(
      "zone_input_candidates_matches_cluster_assignments_rows",
      dataset = "zones.zone_input_candidates,zones.cluster_assignments",
      metric_value = abs(nrow(publications$zone_input_candidates) - nrow(publications$cluster_assignments)),
      pass = zone_input_cluster_row_match,
      details = paste("Zone input rows:", nrow(publications$zone_input_candidates), "Cluster assignment rows:", nrow(publications$cluster_assignments))
    ),
    make_validation_row(
      "contiguity_summary_geometry_row_match",
      dataset = "zones.contiguity_zone_summary,zones.contiguity_zone_geometries",
      metric_value = abs(nrow(publications$contiguity_zone_summary) - nrow(publications$contiguity_zone_geometries)),
      pass = contiguity_row_match,
      details = paste("Contiguity summary rows:", nrow(publications$contiguity_zone_summary), "Geometry rows:", nrow(publications$contiguity_zone_geometries))
    ),
    make_validation_row(
      "cluster_summary_geometry_row_match",
      dataset = "zones.cluster_zone_summary,zones.cluster_zone_geometries",
      metric_value = abs(nrow(publications$cluster_zone_summary) - nrow(publications$cluster_zone_geometries)),
      pass = cluster_row_match,
      details = paste("Cluster summary rows:", nrow(publications$cluster_zone_summary), "Geometry rows:", nrow(publications$cluster_zone_geometries))
    ),
    make_validation_row(
      "contiguity_summary_geometry_market_match",
      dataset = "zones.contiguity_zone_summary,zones.contiguity_zone_geometries",
      metric_value = abs(dplyr::n_distinct(publications$contiguity_zone_summary$market_key) - dplyr::n_distinct(publications$contiguity_zone_geometries$market_key)),
      pass = contiguity_market_match,
      details = paste("Contiguity summary markets:", dplyr::n_distinct(publications$contiguity_zone_summary$market_key), "Geometry markets:", dplyr::n_distinct(publications$contiguity_zone_geometries$market_key))
    ),
    make_validation_row(
      "cluster_summary_geometry_market_match",
      dataset = "zones.cluster_zone_summary,zones.cluster_zone_geometries",
      metric_value = abs(dplyr::n_distinct(publications$cluster_zone_summary$market_key) - dplyr::n_distinct(publications$cluster_zone_geometries$market_key)),
      pass = cluster_market_match,
      details = paste("Cluster summary markets:", dplyr::n_distinct(publications$cluster_zone_summary$market_key), "Geometry markets:", dplyr::n_distinct(publications$cluster_zone_geometries$market_key))
    )
  ) %>%
    mutate(
      build_source = "data_platform/layers/03_zone_build",
      run_timestamp = as.character(Sys.time())
    )

  skipped_markets <- publications$skipped_markets %>%
    mutate(
      build_source = "data_platform/layers/03_zone_build",
      run_timestamp = as.character(Sys.time())
    )

  list(
    validation_results = validation_results,
    skipped_markets = skipped_markets
  )
}

validate_zone_build_layer_publications <- function(publications) {
  distinct_market_count <- function(df) dplyr::n_distinct(df$market_key)
  distinct_cbsa_count <- function(df) dplyr::n_distinct(df$cbsa_code)
  duplicate_key_count <- function(df, key_cols) {
    nrow(df) - dplyr::n_distinct(do.call(paste, c(df[key_cols], sep = "::")))
  }

  zone_input_market_cbsa_counts <- publications$zone_input_candidates %>%
    dplyr::distinct(market_key, cbsa_code) %>%
    dplyr::count(market_key, name = "cbsa_count")

  expected_market_count <- length(publications$profiles)
  skipped_market_count <- nrow(publications$skipped_markets)
  published_states <- sort(unique(publications$zone_input_candidates$state_scope))
  target_states_present <- all(ZONE_BUILD_TARGET_STATES %in% published_states)

  list(
    expected_market_count = expected_market_count,
    published_market_count = distinct_market_count(publications$zone_input_candidates),
    skipped_market_count = skipped_market_count,
    zone_input_market_count = distinct_market_count(publications$zone_input_candidates),
    zone_input_cbsa_count = distinct_cbsa_count(publications$zone_input_candidates),
    contiguity_summary_market_count = distinct_market_count(publications$contiguity_zone_summary),
    cluster_summary_market_count = distinct_market_count(publications$cluster_zone_summary),
    zone_input_key_dupes = duplicate_key_count(publications$zone_input_candidates, c("market_key", "tract_geoid")),
    contiguity_component_key_dupes = duplicate_key_count(publications$contiguity_zone_components, c("market_key", "tract_geoid")),
    contiguity_summary_key_dupes = duplicate_key_count(publications$contiguity_zone_summary, c("market_key", "zone_id")),
    contiguity_geometry_key_dupes = duplicate_key_count(publications$contiguity_zone_geometries, c("market_key", "zone_id")),
    cluster_assignment_key_dupes = duplicate_key_count(publications$cluster_assignments, c("market_key", "tract_geoid")),
    cluster_summary_key_dupes = duplicate_key_count(publications$cluster_zone_summary, c("market_key", "cluster_id")),
    cluster_geometry_key_dupes = duplicate_key_count(publications$cluster_zone_geometries, c("market_key", "cluster_id")),
    one_cbsa_per_market = all(zone_input_market_cbsa_counts$cbsa_count == 1),
    multi_market_present = distinct_market_count(publications$zone_input_candidates) > 1,
    target_states_present = target_states_present,
    skipped_markets = publications$skipped_markets,
    pass = distinct_market_count(publications$zone_input_candidates) > 1 &&
      distinct_market_count(publications$contiguity_zone_summary) == distinct_market_count(publications$zone_input_candidates) &&
      distinct_market_count(publications$cluster_zone_summary) == distinct_market_count(publications$zone_input_candidates) &&
      duplicate_key_count(publications$zone_input_candidates, c("market_key", "tract_geoid")) == 0 &&
      duplicate_key_count(publications$contiguity_zone_components, c("market_key", "tract_geoid")) == 0 &&
      duplicate_key_count(publications$contiguity_zone_summary, c("market_key", "zone_id")) == 0 &&
      duplicate_key_count(publications$contiguity_zone_geometries, c("market_key", "zone_id")) == 0 &&
      duplicate_key_count(publications$cluster_assignments, c("market_key", "tract_geoid")) == 0 &&
      duplicate_key_count(publications$cluster_zone_summary, c("market_key", "cluster_id")) == 0 &&
      duplicate_key_count(publications$cluster_zone_geometries, c("market_key", "cluster_id")) == 0 &&
      all(zone_input_market_cbsa_counts$cbsa_count == 1) &&
      target_states_present
  )
}

publish_zone_build_layer_publications <- function(con, publications) {
  ensure_rof_duckdb_schemas(con)
  qa_summary <- validate_zone_build_layer_publications(publications)
  qa_outputs <- build_zone_build_qa(publications, qa_summary)

  write_duckdb_table(con, "zones", "zone_input_candidates", publications$zone_input_candidates, overwrite = TRUE)
  write_duckdb_table(con, "zones", "contiguity_zone_components", publications$contiguity_zone_components, overwrite = TRUE)
  write_duckdb_table(con, "zones", "contiguity_zone_summary", publications$contiguity_zone_summary, overwrite = TRUE)
  write_duckdb_table(con, "zones", "contiguity_zone_geometries", publications$contiguity_zone_geometries, overwrite = TRUE)
  write_duckdb_table(con, "zones", "cluster_assignments", publications$cluster_assignments, overwrite = TRUE)
  write_duckdb_table(con, "zones", "cluster_zone_summary", publications$cluster_zone_summary, overwrite = TRUE)
  write_duckdb_table(con, "zones", "cluster_zone_geometries", publications$cluster_zone_geometries, overwrite = TRUE)
  write_duckdb_table(con, "qa", "zone_build_validation_results", qa_outputs$validation_results, overwrite = TRUE)
  write_duckdb_table(con, "qa", "zone_build_skipped_markets", qa_outputs$skipped_markets, overwrite = TRUE)

  invisible(
    list(
      zone_input_candidates = nrow(publications$zone_input_candidates),
      contiguity_zone_summary = nrow(publications$contiguity_zone_summary),
      cluster_zone_summary = nrow(publications$cluster_zone_summary),
      markets = dplyr::n_distinct(publications$zone_input_candidates$market_key),
      cbsas = dplyr::n_distinct(publications$zone_input_candidates$cbsa_code),
      qa_validation_results = nrow(qa_outputs$validation_results),
      qa_skipped_markets = nrow(qa_outputs$skipped_markets)
    )
  )
}
