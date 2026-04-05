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

normalize_county_fips <- function(x) {
  out <- suppressWarnings(as.integer(as.character(x)))
  out <- ifelse(is.na(out), NA_integer_, out)
  stringr::str_pad(as.character(out), width = 3, side = "left", pad = "0")
}

normalize_county_code <- function(x) {
  out <- suppressWarnings(as.integer(as.character(x)))
  ifelse(is.na(out), NA_character_, as.character(out))
}

normalize_land_use_code <- function(x) {
  out <- trimws(as.character(x))
  out[out == ""] <- NA_character_
  stringr::str_pad(out, width = 3, side = "left", pad = "0")
}

derive_county_tag <- function(county_fips) {
  count_int <- suppressWarnings(as.integer(as.character(county_fips)))
  ifelse(is.na(count_int), NA_character_, paste0("co_", count_int))
}

normalize_county_name_key <- function(x) {
  out <- stringr::str_to_lower(as.character(x))
  out <- stringr::str_replace_all(out, "[^a-z0-9]", "")
  out <- stringr::str_replace(out, "county$", "")
  out[out == ""] <- NA_character_
  out
}

extract_source_county_name_key <- function(x) {
  stem <- tools::file_path_sans_ext(basename(as.character(x)))
  stem <- stringr::str_replace(stem, "_[0-9]{4}.*$", "")
  normalize_county_name_key(stem)
}

read_market_county_membership <- function(con, profile = get_market_profile()) {
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT market_key, cbsa_code, county_geoid, county_name, state_fips, county_fips, state_abbr ",
      "FROM ref.market_county_membership ",
      "WHERE market_key = ", DBI::dbQuoteString(con, profile$market_key), " ",
      "ORDER BY county_geoid"
    )
  ) %>%
    mutate(
      county_fips = normalize_county_fips(county_fips),
      county_code = normalize_county_code(county_fips),
      county_tag = derive_county_tag(county_fips),
      county_name_key = normalize_county_name_key(county_name)
    )
}

read_land_use_mapping <- function(con) {
  DBI::dbGetQuery(con, "
    SELECT
      land_use_code,
      category,
      description,
      source_system,
      source_path,
      retail_flag,
      retail_subtype,
      review_note,
      reviewed_n_parcels,
      classification_source_path,
      mapping_version,
      mapping_method,
      build_source,
      run_timestamp
    FROM ref.land_use_mapping
  ") %>%
    mutate(
      land_use_code = normalize_land_use_code(land_use_code),
      retail_flag = as.logical(retail_flag)
    )
}

query_market_parcel_tabular <- function(con, market_counties) {
  county_name_sql <- paste(DBI::dbQuoteString(con, toupper(unique(market_counties$county_name))), collapse = ", ")
  state_abbr_sql <- paste(DBI::dbQuoteString(con, unique(market_counties$state_abbr)), collapse = ", ")

  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT ",
      "state, county_name, county_tag, county_geoid, census_block_id, source_file, parcel_id, alt_key, county_code, county_fips, use_code, ",
      "owner_name, owner_addr, phys_addr, just_value, land_value, impro_value, total_value, living_area_sqft, ",
      "sale_qual_code, sale_price1, sale_yr1, sale_mo1, join_key ",
      "FROM rof_parcel.parcel_tabular_clean ",
      "WHERE upper(state) IN (", state_abbr_sql, ") ",
      "AND upper(county_name) IN (", county_name_sql, ")"
    )
  )
}

read_county_geometry_join_qa <- function(parcel_root = resolve_parcel_standardized_root()) {
  qa_path <- file.path(parcel_root, "parcel_geometry_join_qa_county_summary.rds")
  if (!file.exists(qa_path)) {
    return(tibble::tibble())
  }

  readRDS(qa_path) %>%
    as_tibble() %>%
    mutate(
      county_tag = as.character(county_tag),
      county_fips = normalize_county_fips(stringr::str_extract(county_tag, "[0-9]+")),
      county_code = normalize_county_code(county_fips),
      county_name_key = extract_source_county_name_key(source_shp)
    )
}

read_county_load_log <- function(con, market_counties) {
  load_log <- DBI::dbGetQuery(con, "
    SELECT
      ingest_run_id,
      state,
      county_tag,
      county_name,
      county_fips,
      source_county_id,
      source_file,
      source_shp,
      source_shp_path,
      raw_path,
      analysis_keep_duplicates_path,
      analysis_path,
      qa_path,
      duplicate_groups,
      duplicate_rows,
      dissolve_fallback_rows,
      total_rows_raw,
      unmatched_rows_raw,
      unmatched_rate_raw,
      total_rows_analysis,
      unmatched_rows_analysis,
      unmatched_rate_analysis,
      transform_version,
      generated_at,
      pass,
      load_completed_at,
      load_status,
      load_note
    FROM rof_parcel.parcel_county_load_log
  ")

  if (nrow(load_log) == 0) {
    return(tibble::tibble())
  }

  load_log %>%
    as_tibble() %>%
    mutate(
      county_fips = normalize_county_fips(dplyr::coalesce(county_fips, source_county_id)),
      county_code = normalize_county_code(county_fips),
      county_tag = dplyr::coalesce(as.character(county_tag), derive_county_tag(county_fips)),
      county_name_key = normalize_county_name_key(county_name)
    ) %>%
    semi_join(market_counties %>% select(county_name_key), by = "county_name_key")
}

build_parcels_canonical <- function(con, profile = get_market_profile()) {
  market_counties <- read_market_county_membership(con, profile = profile)

  parcel_tabular <- query_market_parcel_tabular(con, market_counties) %>%
    as_tibble() %>%
    mutate(
      state_abbr = toupper(as.character(state)),
      county_geoid_source = as.character(county_geoid),
      county_fips_source = normalize_county_fips(county_fips),
      source_county_code = normalize_county_code(county_code),
      census_block_id = dplyr::na_if(trimws(as.character(census_block_id)), ""),
      join_key = trimws(as.character(join_key)),
      parcel_id = as.character(parcel_id),
      alt_key = as.character(alt_key),
      county_name_source = as.character(county_name),
      county_name_key = normalize_county_name_key(county_name_source),
      land_use_code = normalize_land_use_code(use_code),
      owner_name = as.character(owner_name),
      owner_addr = as.character(owner_addr),
      site_addr = as.character(phys_addr),
      just_value = suppressWarnings(as.numeric(just_value)),
      land_value = suppressWarnings(as.numeric(land_value)),
      impro_value = suppressWarnings(as.numeric(impro_value)),
      total_value = suppressWarnings(as.numeric(total_value)),
      living_area_sqft = suppressWarnings(as.numeric(living_area_sqft)),
      sale_qual_code = as.character(sale_qual_code),
      last_sale_price = suppressWarnings(as.numeric(sale_price1)),
      sale_yr1 = suppressWarnings(as.integer(sale_yr1)),
      sale_mo1 = suppressWarnings(as.integer(sale_mo1)),
      sale_mo1 = dplyr::if_else(!is.na(sale_mo1) & sale_mo1 >= 1L & sale_mo1 <= 12L, sale_mo1, NA_integer_),
      last_sale_date = lubridate::make_date(year = sale_yr1, month = sale_mo1, day = 1L),
      ingest_run_id = NA_character_,
      transform_version = "rof_parcel.parcel_tabular_clean_current",
      qa_missing_join_key = is.na(join_key) | join_key == "",
      qa_zero_county = is.na(source_county_code) | source_county_code == "" | source_county_code == "0",
      source_county_tag = as.character(county_tag),
      parcel_uid = paste0(source_county_code, "::", join_key)
    ) %>%
    semi_join(market_counties %>% select(county_name_key), by = "county_name_key") %>%
    left_join(
      market_counties %>%
        select(
          market_key,
          cbsa_code,
          county_geoid,
          county_name_ref = county_name,
          county_name_key,
          state_fips,
          county_fips,
          state_abbr_ref = state_abbr,
          county_code,
          county_tag_ref = county_tag
        ),
      by = "county_name_key"
    ) %>%
    mutate(
      market_key = dplyr::coalesce(market_key, profile$market_key),
      cbsa_code = dplyr::coalesce(cbsa_code, profile$cbsa_code),
      county_geoid = dplyr::coalesce(.data$county_geoid.y, county_geoid_source),
      county_fips = dplyr::coalesce(.data$county_fips.y, county_fips_source),
      county_code = source_county_code,
      county_tag = dplyr::coalesce(county_tag_ref, derive_county_tag(.data$county_fips.y)),
      county_name = dplyr::coalesce(county_name_ref, county_name_source),
      state_abbr = dplyr::coalesce(state_abbr_ref, state_abbr),
      build_source = "rof_parcel.parcel_tabular_clean filtered by ref.market_county_membership",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      state_abbr,
      state_fips,
      county_fips,
      county_geoid,
      county_code,
      county_tag,
      county_name,
      county_name_key,
      source_county_code,
      source_county_tag,
      county_name_source,
      source_file,
      ingest_run_id,
      transform_version,
      parcel_uid,
      parcel_id,
      alt_key,
      join_key,
      census_block_id,
      land_use_code,
      owner_name,
      owner_addr,
      site_addr,
      living_area_sqft,
      just_value,
      land_value,
      impro_value,
      total_value,
      sale_qual_code,
      last_sale_price,
      last_sale_date,
      qa_missing_join_key,
      qa_zero_county,
      build_source,
      run_timestamp
    ) %>%
    arrange(county_geoid, parcel_uid)

  parcel_duplicates <- parcel_tabular %>%
    count(parcel_uid, name = "n_rows") %>%
    filter(n_rows > 1)

  canonical <- parcel_tabular %>%
    distinct(parcel_uid, .keep_all = TRUE)

  list(
    canonical = canonical,
    duplicates = parcel_duplicates,
    market_counties = market_counties
  )
}

build_parcel_join_qa <- function(market_counties, geometry_join_qa) {
  if (nrow(geometry_join_qa) == 0) {
    return(
      market_counties %>%
        transmute(
          market_key,
          cbsa_code,
          state_abbr,
          state_fips,
          county_fips,
          county_geoid,
          county_name,
          county_tag,
          source_shp = NA_character_,
          output_dir = NA_character_,
          raw_path = NA_character_,
          analysis_path = NA_character_,
          qa_path = NA_character_,
          total_rows_raw = NA_real_,
          unmatched_rows_raw = NA_real_,
          unmatched_rate_raw = NA_real_,
          total_rows_analysis = NA_real_,
          unmatched_rows_analysis = NA_real_,
          unmatched_rate_analysis = NA_real_,
          pass = NA
        ) %>%
        mutate(
          build_source = "parcel_geometry_join_qa_county_summary.rds_missing",
          run_timestamp = as.character(Sys.time())
        )
    )
  }

  market_counties %>%
    left_join(
      geometry_join_qa %>%
        select(
          county_name_key,
          source_county_tag = county_tag,
          source_county_code = county_code,
          source_shp,
          output_dir,
          raw_path,
          analysis_path,
          qa_path,
          total_rows_raw,
          unmatched_rows_raw,
          unmatched_rate_raw,
          total_rows_analysis,
          unmatched_rows_analysis,
          unmatched_rate_analysis,
          pass
        ),
      by = "county_name_key"
    ) %>%
    mutate(
      build_source = "parcel_geometry_join_qa_county_summary.rds",
      run_timestamp = as.character(Sys.time())
    ) %>%
    arrange(county_geoid)
}

build_parcel_lineage <- function(parcels_canonical, parcel_join_qa, load_log) {
  parcel_counts <- parcels_canonical %>%
    group_by(market_key, county_geoid, county_fips) %>%
    summarise(
      parcel_rows = n(),
      distinct_parcels = n_distinct(parcel_uid),
      .groups = "drop"
    )

  parcel_join_qa %>%
    left_join(parcel_counts, by = c("market_key", "county_geoid", "county_fips")) %>%
    left_join(load_log, by = "county_name_key") %>%
    mutate(
      county_fips = dplyr::coalesce(.data$county_fips.x, .data$county_fips.y),
      county_tag = dplyr::coalesce(.data$county_tag.x, .data$county_tag.y),
      county_name = dplyr::coalesce(.data$county_name.x, .data$county_name.y),
      source_file = dplyr::coalesce(.data$source_file, NA_character_),
      source_shp = dplyr::coalesce(.data$source_shp.x, .data$source_shp.y),
      raw_path = dplyr::coalesce(.data$raw_path.x, .data$raw_path.y),
      analysis_path = dplyr::coalesce(.data$analysis_path.x, .data$analysis_path.y),
      qa_path = dplyr::coalesce(.data$qa_path.x, .data$qa_path.y),
      total_rows_raw = dplyr::coalesce(.data$total_rows_raw.x, .data$total_rows_raw.y),
      unmatched_rows_raw = dplyr::coalesce(.data$unmatched_rows_raw.x, .data$unmatched_rows_raw.y),
      unmatched_rate_raw = dplyr::coalesce(.data$unmatched_rate_raw.x, .data$unmatched_rate_raw.y),
      total_rows_analysis = dplyr::coalesce(.data$total_rows_analysis.x, .data$total_rows_analysis.y),
      unmatched_rows_analysis = dplyr::coalesce(.data$unmatched_rows_analysis.x, .data$unmatched_rows_analysis.y),
      unmatched_rate_analysis = dplyr::coalesce(.data$unmatched_rate_analysis.x, .data$unmatched_rate_analysis.y),
      pass = dplyr::coalesce(.data$pass.x, .data$pass.y),
      parcel_rows = dplyr::coalesce(parcel_rows, 0L),
      distinct_parcels = dplyr::coalesce(distinct_parcels, 0L),
      lineage_source = dplyr::if_else(!is.na(load_status), "rof_parcel.parcel_county_load_log", "parcel_geometry_join_qa_county_summary.rds"),
      build_source = "parcel geometry QA + county load log + parcel counts",
      run_timestamp = as.character(Sys.time())
    ) %>%
    select(
      market_key,
      cbsa_code,
      state_abbr,
      state_fips,
      county_fips,
      county_geoid,
      county_name,
      county_tag,
      source_file,
      source_shp,
      source_shp_path,
      raw_path,
      analysis_keep_duplicates_path,
      analysis_path,
      qa_path,
      transform_version,
      generated_at,
      load_completed_at,
      load_status,
      load_note,
      parcel_rows,
      distinct_parcels,
      duplicate_groups,
      duplicate_rows,
      dissolve_fallback_rows,
      total_rows_raw,
      unmatched_rows_raw,
      unmatched_rate_raw,
      total_rows_analysis,
      unmatched_rows_analysis,
      unmatched_rate_analysis,
      pass,
      lineage_source,
      build_source,
      run_timestamp
    ) %>%
    arrange(county_geoid)
}

attach_retail_classification <- function(parcels_canonical, land_use_mapping) {
  parcels_canonical %>%
    left_join(
      land_use_mapping %>%
        select(
          land_use_code,
          land_use_category = category,
          land_use_description = description,
          retail_flag,
          retail_subtype,
          review_note,
          mapping_version,
          mapping_method,
          classification_source_path
        ),
      by = "land_use_code"
    ) %>%
    mutate(
      retail_flag = dplyr::coalesce(retail_flag, FALSE),
      retail_subtype = dplyr::if_else(retail_flag & is.na(retail_subtype), "retail_uncategorized", retail_subtype),
      parcel_segment = dplyr::if_else(retail_flag, "Retail parcel", "Residential/other parcel"),
      build_source = "parcel.parcels_canonical + ref.land_use_mapping",
      run_timestamp = as.character(Sys.time())
    ) %>%
    arrange(county_geoid, parcel_uid)
}

build_retail_parcels <- function(parcels_canonical_classified) {
  parcels_canonical_classified %>%
    filter(retail_flag) %>%
    arrange(county_geoid, parcel_uid)
}

build_parcel_qa <- function(products) {
  canonical_unique <- validate_unique_key(products$parcels_canonical, "parcel_uid", "parcel.parcels_canonical")
  missing_join_key_count <- sum(products$parcels_canonical$qa_missing_join_key, na.rm = TRUE)
  missing_county_geoid_count <- sum(is.na(products$parcels_canonical$county_geoid) | !nzchar(products$parcels_canonical$county_geoid))
  unmapped_use_codes <- products$parcels_canonical %>%
    filter(!is.na(land_use_code)) %>%
    anti_join(products$land_use_mapping %>% select(land_use_code), by = "land_use_code") %>%
    count(land_use_code, sort = TRUE, name = "parcel_count") %>%
    mutate(
      build_source = "parcel.parcels_canonical anti-join ref.land_use_mapping",
      run_timestamp = as.character(Sys.time())
    )

  join_qa_missing_counties <- sum(is.na(products$parcel_join_qa$analysis_path) | !nzchar(products$parcel_join_qa$analysis_path))
  join_qa_failed_counties <- sum(products$parcel_join_qa$pass == FALSE, na.rm = TRUE)
  join_qa_high_unmatched <- sum(
    !is.na(products$parcel_join_qa$unmatched_rate_analysis) &
      products$parcel_join_qa$unmatched_rate_analysis > 0.02,
    na.rm = TRUE
  )
  zero_parcel_counties <- sum(products$parcel_lineage$distinct_parcels == 0, na.rm = TRUE)

  validation_results <- dplyr::bind_rows(
    make_validation_row(
      "parcel_canonical_unique_parcel_uid",
      dataset = "parcel.parcels_canonical",
      metric_value = canonical_unique$duplicates,
      pass = isTRUE(canonical_unique$pass),
      details = paste("Duplicate parcel_uid rows:", canonical_unique$duplicates)
    ),
    make_validation_row(
      "parcel_canonical_missing_join_key",
      dataset = "parcel.parcels_canonical",
      metric_value = missing_join_key_count,
      pass = missing_join_key_count == 0,
      details = paste("Rows with missing join_key:", missing_join_key_count)
    ),
    make_validation_row(
      "parcel_canonical_missing_county_geoid",
      dataset = "parcel.parcels_canonical",
      metric_value = missing_county_geoid_count,
      pass = missing_county_geoid_count == 0,
      details = paste("Rows with missing county_geoid:", missing_county_geoid_count)
    ),
    make_validation_row(
      "parcel_land_use_mapping_unmapped_codes",
      dataset = "parcel.retail_parcels",
      metric_value = nrow(unmapped_use_codes),
      pass = nrow(unmapped_use_codes) == 0,
      details = paste("Distinct unmapped land_use_code values:", nrow(unmapped_use_codes))
    ),
    make_validation_row(
      "parcel_join_qa_missing_counties",
      dataset = "parcel.parcel_join_qa",
      metric_value = join_qa_missing_counties,
      pass = join_qa_missing_counties == 0,
      details = paste("Market counties without geometry QA lineage:", join_qa_missing_counties)
    ),
    make_validation_row(
      "parcel_join_qa_failed_counties",
      dataset = "parcel.parcel_join_qa",
      metric_value = join_qa_failed_counties,
      pass = join_qa_failed_counties == 0,
      details = paste("Counties with geometry QA pass == FALSE:", join_qa_failed_counties)
    ),
    make_validation_row(
      "parcel_join_qa_high_unmatched_rate_counties",
      severity = "warning",
      dataset = "parcel.parcel_join_qa",
      metric_value = join_qa_high_unmatched,
      pass = join_qa_high_unmatched == 0,
      details = paste("Counties with unmatched_rate_analysis > 0.02:", join_qa_high_unmatched)
    ),
    make_validation_row(
      "parcel_lineage_zero_parcel_counties",
      severity = "warning",
      dataset = "parcel.parcel_lineage",
      metric_value = zero_parcel_counties,
      pass = zero_parcel_counties == 0,
      details = paste("Market counties with zero published parcels:", zero_parcel_counties)
    )
  ) %>%
    mutate(
      build_source = "data_platform/layers/04_parcel_standardization",
      run_timestamp = as.character(Sys.time())
    )

  list(
    validation_results = validation_results,
    unmapped_use_codes = unmapped_use_codes
  )
}

build_parcel_standardization_products <- function(con, profile = get_market_profile(), parcel_root = resolve_parcel_standardized_root()) {
  parcel_build <- build_parcels_canonical(con, profile = profile)
  land_use_mapping <- read_land_use_mapping(con)
  geometry_join_qa <- read_county_geometry_join_qa(parcel_root = parcel_root)
  parcel_join_qa <- build_parcel_join_qa(parcel_build$market_counties, geometry_join_qa)
  load_log <- read_county_load_log(con, parcel_build$market_counties)
  parcels_canonical <- attach_retail_classification(parcel_build$canonical, land_use_mapping)
  parcel_lineage <- build_parcel_lineage(parcels_canonical, parcel_join_qa, load_log)
  retail_parcels <- build_retail_parcels(parcels_canonical)

  products <- list(
    profile = profile,
    market_counties = parcel_build$market_counties,
    land_use_mapping = land_use_mapping,
    parcels_canonical = parcels_canonical,
    parcel_uid_duplicates = parcel_build$duplicates,
    parcel_join_qa = parcel_join_qa,
    parcel_lineage = parcel_lineage,
    retail_parcels = retail_parcels
  )

  qa_outputs <- build_parcel_qa(products)
  products$qa_validation_results <- qa_outputs$validation_results
  products$qa_unmapped_use_codes <- qa_outputs$unmapped_use_codes
  products
}

publish_parcel_standardization_products <- function(con, products) {
  ensure_rof_duckdb_schemas(con)

  write_duckdb_table(con, "parcel", "parcels_canonical", products$parcels_canonical, overwrite = TRUE)
  write_duckdb_table(con, "parcel", "parcel_join_qa", products$parcel_join_qa, overwrite = TRUE)
  write_duckdb_table(con, "parcel", "parcel_lineage", products$parcel_lineage, overwrite = TRUE)
  write_duckdb_table(con, "parcel", "retail_parcels", products$retail_parcels, overwrite = TRUE)
  write_duckdb_table(con, "qa", "parcel_validation_results", products$qa_validation_results, overwrite = TRUE)
  write_duckdb_table(con, "qa", "parcel_unmapped_use_codes", products$qa_unmapped_use_codes, overwrite = TRUE)

  list(
    parcels_canonical = nrow(products$parcels_canonical),
    parcel_join_qa = nrow(products$parcel_join_qa),
    parcel_lineage = nrow(products$parcel_lineage),
    retail_parcels = nrow(products$retail_parcels),
    qa_validation_results = nrow(products$qa_validation_results),
    qa_unmapped_use_codes = nrow(products$qa_unmapped_use_codes)
  )
}
