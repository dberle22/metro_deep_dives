source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()
source("notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features/foundation_feature_workflow.R")

platform_helpers_path <- "notebooks/retail_opportunity_finder/data_platform/shared/platform_helpers.R"
if (!file.exists(platform_helpers_path)) {
  stop("Missing data platform helper file.", call. = FALSE)
}
source(platform_helpers_path)

TRACT_SCORING_LAYER_ROOT <- "notebooks/retail_opportunity_finder/data_platform/layers/02_tract_scoring"
TRACT_SCORING_TABLE_ROOT <- file.path(TRACT_SCORING_LAYER_ROOT, "tables")
TRACT_SCORING_TARGET_STATES <- c("FL", "GA", "NC", "SC")

resolve_tract_scoring_table_asset <- function(table_name, extension) {
  path <- file.path(TRACT_SCORING_TABLE_ROOT, paste0(table_name, ".", extension))
  if (!file.exists(path)) {
    stop(sprintf("Tract scoring layer table asset not found: %s", path), call. = FALSE)
  }
  path
}

source(resolve_tract_scoring_table_asset("scoring.tract_scores", "R"))
source(resolve_tract_scoring_table_asset("scoring.cluster_seed_tracts", "R"))

build_generated_market_profile <- function(cbsa_code, cbsa_name, primary_state_abbr) {
  market_key <- paste0("cbsa_", cbsa_code)
  market_name <- if (!is.na(cbsa_name) && nzchar(cbsa_name)) cbsa_name else paste("CBSA", cbsa_code)

  list(
    market_key = market_key,
    cbsa_code = cbsa_code,
    state_scope = c(primary_state_abbr),
    benchmark_region_type = "census_division",
    benchmark_region_value = "South Atlantic",
    benchmark_region_label = "South Atlantic",
    peers = c(cbsa_code),
    labels = list(
      cbsa_name = market_name,
      cbsa_name_full = market_name,
      market_name = paste0(market_name, " market"),
      peer_group = "Southeast scoring universe",
      target_flag = market_name,
      us_label = "United States (CBSAs)"
    )
  )
}

resolve_scoring_market_profiles <- function(con, target_states = TRACT_SCORING_TARGET_STATES) {
  state_sql <- paste(sprintf("'%s'", target_states), collapse = ", ")
  cbsa_universe <- DBI::dbGetQuery(
    con,
    paste0(
      "WITH tract_cbsas AS (",
      "  SELECT DISTINCT cbsa_code",
      "  FROM foundation.tract_features",
      "  WHERE cbsa_code IS NOT NULL AND cbsa_code <> ''",
      "), cbsa_meta AS (",
      "  SELECT DISTINCT cbsa_code, cbsa_name, primary_state_abbr",
      "  FROM foundation.cbsa_features",
      "  WHERE primary_state_abbr IN (", state_sql, ")",
      ") ",
      "SELECT meta.cbsa_code, meta.cbsa_name, meta.primary_state_abbr ",
      "FROM cbsa_meta meta ",
      "INNER JOIN tract_cbsas tract ON meta.cbsa_code = tract.cbsa_code ",
      "ORDER BY meta.primary_state_abbr, meta.cbsa_code"
    )
  )

  profile_lookup <- setNames(MARKET_PROFILES, vapply(MARKET_PROFILES, `[[`, character(1), "cbsa_code"))

  lapply(seq_len(nrow(cbsa_universe)), function(i) {
    row <- cbsa_universe[i, , drop = FALSE]
    existing <- profile_lookup[[row$cbsa_code[[1]]]]

    if (!is.null(existing)) {
      existing
    } else {
      build_generated_market_profile(
        cbsa_code = row$cbsa_code[[1]],
        cbsa_name = row$cbsa_name[[1]],
        primary_state_abbr = row$primary_state_abbr[[1]]
      )
    }
  })
}

build_tract_scoring_products <- function(
    con,
    profile = get_market_profile(),
    model_params = MODEL_PARAMS,
    tract_features_sql = resolve_foundation_table_asset("foundation.tract_features", "sql"),
    tract_scores_asset = resolve_tract_scoring_table_asset("scoring.tract_scores", "R"),
    cluster_seed_asset = resolve_tract_scoring_table_asset("scoring.cluster_seed_tracts", "R"),
    include_geometry = TRUE) {
  use_foundation_tract_features <- duckdb_table_exists(con, "foundation", "tract_features")

  tract_features <- if (use_foundation_tract_features) {
    DBI::dbGetQuery(
      con,
      glue::glue("SELECT * FROM foundation.tract_features WHERE cbsa_code = '{profile$cbsa_code}'")
    ) %>%
      select(-any_of(c("market_key", "state_scope", "build_source", "run_timestamp")))
  } else {
    query_tract_features_for_market(con, sql_path = tract_features_sql, cbsa_code = profile$cbsa_code, target_year = TARGET_YEAR)
  }
  assert_required_columns(tract_features, REQUIRED_COLUMNS$tract_features, "tract_features")

  tract_score_outputs <- build_tract_scores_product(
    tract_features = tract_features,
    profile = profile,
    model_params = model_params
  )

  cluster_seed_tracts <- build_cluster_seed_tracts_product(
    scored_tracts = tract_score_outputs$scored_tracts,
    cluster_top_share = model_params$cluster_top_share
  )

  price_hist_input <- tract_features %>%
    select(tract_geoid, price_proxy_pctl, eligible_v1) %>%
    filter(!is.na(price_proxy_pctl))

  growth_hist_input <- tract_features %>%
    select(tract_geoid, pop_growth_3yr, eligible_v1) %>%
    filter(!is.na(pop_growth_3yr))

  tract_sf <- NULL
  if (isTRUE(include_geometry)) {
    tract_wkb <- query_tract_geometry_wkb(con, profile = profile, cbsa_code = profile$cbsa_code)
    tract_sf <- sf_from_wkb_df(tract_wkb, c("tract_geoid")) %>%
      left_join(
        tract_features %>% select(tract_geoid, eligible_v1),
        by = "tract_geoid"
      )
  }

  list(
    run_metadata = run_metadata(),
    profile = profile,
    tract_features = tract_features,
    funnel_counts = tract_score_outputs$funnel_counts,
    eligible_tracts = tract_score_outputs$eligible_tracts,
    scored_tracts = tract_score_outputs$scored_tracts,
    top_tracts = tract_score_outputs$top_tracts,
    cluster_seed_tracts = cluster_seed_tracts,
    tract_scores = tract_score_outputs$tract_scores,
    tract_component_scores = tract_score_outputs$tract_scores,
    price_hist_input = price_hist_input,
    growth_hist_input = growth_hist_input,
    tract_sf = tract_sf,
    build_assets = list(
      tract_scores = tract_scores_asset,
      cluster_seed_tracts = cluster_seed_asset
    )
  )
}

publish_tract_scoring_products <- function(con, products) {
  ensure_rof_duckdb_schemas(con)

  tract_scores_tbl <- products$tract_scores %>%
    prepend_market_metadata(
      profile = products$profile,
      build_source = sub("^notebooks/retail_opportunity_finder/", "", products$build_assets$tract_scores)
    )
  cluster_seed_tbl <- products$cluster_seed_tracts %>%
    prepend_market_metadata(
      profile = products$profile,
      build_source = sub("^notebooks/retail_opportunity_finder/", "", products$build_assets$cluster_seed_tracts)
    )

  write_duckdb_table(con, "scoring", "tract_scores", tract_scores_tbl, overwrite = TRUE)
  write_duckdb_table(con, "scoring", "cluster_seed_tracts", cluster_seed_tbl, overwrite = TRUE)

  invisible(
    list(
      tract_scores = nrow(tract_scores_tbl),
      cluster_seed_tracts = nrow(cluster_seed_tbl)
    )
  )
}

build_tract_scoring_layer_publications <- function(
    con,
    profiles = resolve_scoring_market_profiles(con),
    model_params = MODEL_PARAMS) {
  tract_scores_asset <- resolve_tract_scoring_table_asset("scoring.tract_scores", "R")
  cluster_seed_asset <- resolve_tract_scoring_table_asset("scoring.cluster_seed_tracts", "R")

  per_market <- lapply(profiles, function(profile) {
    products <- build_tract_scoring_products(
      con,
      profile = profile,
      model_params = model_params,
      tract_scores_asset = tract_scores_asset,
      cluster_seed_asset = cluster_seed_asset,
      include_geometry = FALSE
    )

    tract_scores_tbl <- products$tract_scores %>%
      prepend_market_metadata(
        profile = profile,
        build_source = sub("^notebooks/retail_opportunity_finder/", "", tract_scores_asset)
      )

    cluster_seed_tbl <- products$cluster_seed_tracts %>%
      prepend_market_metadata(
        profile = profile,
        build_source = sub("^notebooks/retail_opportunity_finder/", "", cluster_seed_asset)
      )

    list(
      profile = profile,
      tract_scores = tract_scores_tbl,
      cluster_seed_tracts = cluster_seed_tbl,
      summary = tibble::tibble(
        market_key = profile$market_key,
        cbsa_code = profile$cbsa_code,
        state_scope = format_state_scope(profile),
        tract_score_rows = nrow(tract_scores_tbl),
        cluster_seed_rows = nrow(cluster_seed_tbl)
      )
    )
  })

  list(
    profiles = profiles,
    tract_scores = dplyr::bind_rows(lapply(per_market, `[[`, "tract_scores")),
    cluster_seed_tracts = dplyr::bind_rows(lapply(per_market, `[[`, "cluster_seed_tracts")),
    market_summary = dplyr::bind_rows(lapply(per_market, `[[`, "summary")),
    build_assets = list(
      tract_scores = tract_scores_asset,
      cluster_seed_tracts = cluster_seed_asset
    )
  )
}

validate_tract_scoring_layer_publications <- function(publications, cluster_top_share = MODEL_PARAMS$cluster_top_share) {
  tract_scores <- publications$tract_scores
  cluster_seeds <- publications$cluster_seed_tracts

  tract_score_key_dupes <- nrow(tract_scores) -
    dplyr::n_distinct(paste(tract_scores$market_key, tract_scores$tract_geoid, sep = "::"))
  cluster_seed_key_dupes <- nrow(cluster_seeds) -
    dplyr::n_distinct(paste(cluster_seeds$market_key, cluster_seeds$tract_geoid, sep = "::"))

  market_cbsa_counts <- tract_scores %>%
    dplyr::distinct(market_key, cbsa_code) %>%
    dplyr::count(market_key, name = "cbsa_count")

  cluster_cutoff_check <- tract_scores %>%
    dplyr::count(market_key, name = "tract_score_rows") %>%
    dplyr::left_join(
      cluster_seeds %>% dplyr::count(market_key, name = "cluster_seed_rows"),
      by = "market_key"
    ) %>%
    dplyr::mutate(
      cluster_seed_rows = dplyr::coalesce(cluster_seed_rows, 0L),
      expected_cluster_seed_rows = ceiling(tract_score_rows * cluster_top_share),
      pass = cluster_seed_rows == expected_cluster_seed_rows
    )

  list(
    market_count = dplyr::n_distinct(tract_scores$market_key),
    cbsa_count = dplyr::n_distinct(tract_scores$cbsa_code),
    tract_score_key_dupes = tract_score_key_dupes,
    cluster_seed_key_dupes = cluster_seed_key_dupes,
    one_cbsa_per_market = all(market_cbsa_counts$cbsa_count == 1),
    multi_market_present = dplyr::n_distinct(tract_scores$market_key) > 1,
    cluster_cutoff_check = cluster_cutoff_check,
    pass = tract_score_key_dupes == 0 &&
      cluster_seed_key_dupes == 0 &&
      all(market_cbsa_counts$cbsa_count == 1) &&
      dplyr::n_distinct(tract_scores$market_key) > 1 &&
      all(cluster_cutoff_check$pass)
  )
}

publish_tract_scoring_layer_publications <- function(con, publications) {
  ensure_rof_duckdb_schemas(con)
  write_duckdb_table(con, "scoring", "tract_scores", publications$tract_scores, overwrite = TRUE)
  write_duckdb_table(con, "scoring", "cluster_seed_tracts", publications$cluster_seed_tracts, overwrite = TRUE)

  invisible(
    list(
      tract_scores = nrow(publications$tract_scores),
      cluster_seed_tracts = nrow(publications$cluster_seed_tracts),
      markets = dplyr::n_distinct(publications$tract_scores$market_key),
      cbsas = dplyr::n_distinct(publications$tract_scores$cbsa_code)
    )
  )
}
