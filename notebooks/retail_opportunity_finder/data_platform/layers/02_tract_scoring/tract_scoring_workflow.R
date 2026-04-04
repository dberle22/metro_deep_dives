source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

platform_helpers_path <- "notebooks/retail_opportunity_finder/data_platform/shared/platform_helpers.R"
if (!file.exists(platform_helpers_path)) {
  stop("Missing data platform helper file.", call. = FALSE)
}
source(platform_helpers_path)

impute_with_median <- function(x) {
  med <- stats::median(x, na.rm = TRUE)
  dplyr::if_else(is.na(x), med, x)
}

make_why_tags <- function(df, model_params = MODEL_PARAMS) {
  growth_cut <- stats::quantile(df$pop_growth_3yr, 0.75, na.rm = TRUE)
  units_cut <- stats::quantile(df$units_per_1k_3yr, 0.75, na.rm = TRUE)
  commute_cut <- stats::quantile(df$commute_intensity_b, 0.75, na.rm = TRUE)
  income_cut <- stats::quantile(df$median_hh_income, 0.75, na.rm = TRUE)

  df %>%
    mutate(
      why_growth = pop_growth_3yr >= growth_cut,
      why_units = units_per_1k_3yr >= units_cut,
      why_headroom = density_pctl <= model_params$max_density_percentile,
      why_price = price_proxy_pctl <= 0.50,
      why_commute = commute_intensity_b >= commute_cut,
      why_income = median_hh_income >= income_cut
    ) %>%
    rowwise() %>%
    mutate(
      why_tags = paste(
        c(
          if (isTRUE(why_growth)) "High growth" else NA_character_,
          if (isTRUE(why_units)) "High housing pipeline" else NA_character_,
          if (isTRUE(why_headroom)) "Low density headroom" else NA_character_,
          if (isTRUE(why_price)) "Moderate price pressure" else NA_character_,
          if (isTRUE(why_commute)) "High commute exposure" else NA_character_,
          if (isTRUE(why_income)) "Strong household income" else NA_character_
        ) %>% stats::na.omit(),
        collapse = " | "
      )
    ) %>%
    ungroup() %>%
    mutate(why_tags = if_else(why_tags == "", "Balanced profile", why_tags))
}

build_tract_scoring_products <- function(
    con,
    profile = get_market_profile(),
    model_params = MODEL_PARAMS,
    tract_features_sql = resolve_sql_path("tract_features")) {
  tract_features <- query_df_sql_file(con, tract_features_sql)
  assert_required_columns(tract_features, REQUIRED_COLUMNS$tract_features, "tract_features")

  weights <- model_params$weights
  top_n <- model_params$top_n_tracts
  cluster_top_share <- model_params$cluster_top_share

  funnel_counts <- dplyr::tibble(
    step = c(
      "All tracts",
      "After growth gate",
      "After growth + price gates",
      "After growth + price + density gates",
      "Eligible (v1)"
    ),
    step_order = 1:5,
    tracts_remaining = c(
      nrow(tract_features),
      sum(tract_features$gate_pop == 1, na.rm = TRUE),
      sum(tract_features$gate_pop == 1 & tract_features$gate_price == 1, na.rm = TRUE),
      sum(tract_features$gate_pop == 1 & tract_features$gate_price == 1 & tract_features$gate_density == 1, na.rm = TRUE),
      sum(tract_features$eligible_v1 == 1, na.rm = TRUE)
    )
  )

  eligible_tracts <- tract_features %>%
    filter(eligible_v1 == 1) %>%
    mutate(
      growth_raw = pop_growth_3yr,
      units_raw = units_per_1k_3yr,
      headroom_raw = -pop_density,
      price_raw = -price_proxy_pctl,
      commute_raw = commute_intensity_b,
      income_raw = median_hh_income
    )

  scored_tracts <- tract_features %>%
    mutate(
      growth_raw = pop_growth_3yr,
      units_raw = units_per_1k_3yr,
      headroom_raw = -pop_density,
      price_raw = -price_proxy_pctl,
      commute_raw = commute_intensity_b,
      income_raw = median_hh_income
    ) %>%
    mutate(
      growth_scoring = impute_with_median(growth_raw),
      units_scoring = impute_with_median(units_raw),
      headroom_scoring = impute_with_median(headroom_raw),
      price_scoring = impute_with_median(price_raw),
      commute_scoring = impute_with_median(commute_raw),
      income_scoring = impute_with_median(income_raw)
    ) %>%
    mutate(
      z_growth = zscore(growth_scoring),
      z_units = zscore(units_scoring),
      z_headroom = zscore(headroom_scoring),
      z_price = zscore(price_scoring),
      z_commute = zscore(commute_scoring),
      z_income = zscore(income_scoring)
    ) %>%
    mutate(
      contrib_growth = weights[["growth"]] * z_growth,
      contrib_units = weights[["units"]] * z_units,
      contrib_headroom = weights[["headroom"]] * z_headroom,
      contrib_price = weights[["price"]] * z_price,
      contrib_commute = weights[["commute"]] * z_commute,
      contrib_income = weights[["income"]] * z_income,
      tract_score = contrib_growth + contrib_units + contrib_headroom + contrib_price + contrib_commute + contrib_income
    ) %>%
    arrange(desc(tract_score)) %>%
    mutate(tract_rank = row_number()) %>%
    make_why_tags(model_params = model_params)

  cluster_cutoff_n <- ceiling(nrow(scored_tracts) * cluster_top_share)

  cluster_seed_tracts <- scored_tracts %>%
    arrange(desc(tract_score)) %>%
    mutate(
      cluster_seed_rank = row_number(),
      is_cluster_seed = cluster_seed_rank <= cluster_cutoff_n,
      cluster_top_share = cluster_top_share,
      cluster_cutoff_n = cluster_cutoff_n
    ) %>%
    filter(is_cluster_seed) %>%
    select(
      tract_geoid,
      tract_score,
      tract_rank,
      cluster_seed_rank,
      cluster_top_share,
      cluster_cutoff_n,
      eligible_v1
    )

  top_tracts <- scored_tracts %>%
    filter(eligible_v1 == 1) %>%
    arrange(desc(tract_score)) %>%
    mutate(tract_rank = row_number()) %>%
    slice_head(n = top_n) %>%
    select(
      tract_rank,
      tract_geoid,
      tract_score,
      pop_growth_3yr,
      units_per_1k_3yr,
      pop_density,
      price_proxy_pctl,
      commute_intensity_b,
      median_hh_income,
      contrib_growth,
      contrib_units,
      contrib_headroom,
      contrib_price,
      contrib_commute,
      contrib_income,
      why_tags
    )

  tract_component_score_table <- tract_features %>%
    left_join(
      scored_tracts %>%
        select(
          tract_geoid,
          growth_raw,
          units_raw,
          headroom_raw,
          price_raw,
          commute_raw,
          income_raw,
          z_growth,
          z_units,
          z_headroom,
          z_price,
          z_commute,
          z_income,
          contrib_growth,
          contrib_units,
          contrib_headroom,
          contrib_price,
          contrib_commute,
          contrib_income,
          tract_score,
          tract_rank,
          why_tags
        ),
      by = "tract_geoid"
    ) %>%
    mutate(
      cbsa_code = as.character(cbsa_code),
      is_scored = !is.na(tract_score),
      target_cbsa = profile$cbsa_code
    ) %>%
    select(
      target_cbsa,
      cbsa_code,
      county_geoid,
      tract_geoid,
      year,
      eligible_v1,
      gate_pop,
      gate_price,
      gate_density,
      pop_growth_3yr,
      pop_growth_5yr,
      units_per_1k_3yr,
      pop_density,
      price_proxy_pctl,
      commute_intensity_b,
      median_hh_income,
      growth_raw,
      units_raw,
      headroom_raw,
      price_raw,
      commute_raw,
      income_raw,
      z_growth,
      z_units,
      z_headroom,
      z_price,
      z_commute,
      z_income,
      contrib_growth,
      contrib_units,
      contrib_headroom,
      contrib_price,
      contrib_commute,
      contrib_income,
      tract_score,
      tract_rank,
      why_tags,
      is_scored
    )

  price_hist_input <- tract_features %>%
    select(tract_geoid, price_proxy_pctl, eligible_v1) %>%
    filter(!is.na(price_proxy_pctl))

  growth_hist_input <- tract_features %>%
    select(tract_geoid, pop_growth_3yr, eligible_v1) %>%
    filter(!is.na(pop_growth_3yr))

  tract_wkb <- query_tract_geometry_wkb(con, profile = profile, cbsa_code = profile$cbsa_code)
  tract_sf <- sf_from_wkb_df(tract_wkb, c("tract_geoid")) %>%
    left_join(
      tract_features %>% select(tract_geoid, eligible_v1),
      by = "tract_geoid"
    )

  list(
    run_metadata = run_metadata(),
    profile = profile,
    tract_features = tract_features,
    funnel_counts = funnel_counts,
    eligible_tracts = eligible_tracts,
    scored_tracts = scored_tracts,
    top_tracts = top_tracts,
    cluster_seed_tracts = cluster_seed_tracts,
    tract_component_scores = tract_component_score_table,
    price_hist_input = price_hist_input,
    growth_hist_input = growth_hist_input,
    tract_sf = tract_sf
  )
}

publish_tract_scoring_products <- function(con, products, build_source = "data_platform/layers/02_tract_scoring") {
  ensure_rof_duckdb_schemas(con)

  tract_scores_tbl <- products$tract_component_scores %>%
    prepend_market_metadata(profile = products$profile, build_source = build_source)
  cluster_seed_tbl <- products$cluster_seed_tracts %>%
    prepend_market_metadata(profile = products$profile, build_source = build_source)

  write_duckdb_table(con, "scoring", "tract_scores", tract_scores_tbl, overwrite = TRUE)
  write_duckdb_table(con, "scoring", "cluster_seed_tracts", cluster_seed_tbl, overwrite = TRUE)

  invisible(
    list(
      tract_scores = nrow(tract_scores_tbl),
      cluster_seed_tracts = nrow(cluster_seed_tbl)
    )
  )
}
