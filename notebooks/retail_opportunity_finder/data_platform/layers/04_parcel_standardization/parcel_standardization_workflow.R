source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

platform_helpers_path <- "notebooks/retail_opportunity_finder/data_platform/shared/platform_helpers.R"
if (!file.exists(platform_helpers_path)) {
  stop("Missing data platform helper file.", call. = FALSE)
}
source(platform_helpers_path)

table_asset_paths <- c(
  "notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/parcel.parcels_canonical.R",
  "notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/parcel.parcel_lineage.R",
  "notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/qa.parcel_unmapped_use_codes.R",
  "notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/qa.parcel_validation_results.R",
  "notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/archive/parcel.parcel_join_qa.R",
  "notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/archive/parcel.retail_parcels.R"
)

missing_table_assets <- table_asset_paths[!file.exists(table_asset_paths)]
if (length(missing_table_assets) > 0) {
  stop(
    paste(
      "Missing Layer 04 table asset file(s):",
      paste(missing_table_assets, collapse = ", ")
    ),
    call. = FALSE
  )
}

invisible(lapply(table_asset_paths, source))

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

read_market_county_membership <- function(con) {
  DBI::dbGetQuery(
    con,
    paste0(
      "SELECT market_key, cbsa_code, county_geoid, county_name, state_fips, county_fips, state_abbr ",
      "FROM ref.market_county_membership ",
      "ORDER BY market_key, county_geoid"
    )
  ) %>%
    mutate(
      county_fips = normalize_county_fips(county_fips),
      county_code = normalize_county_code(county_fips),
      county_tag = derive_county_tag(county_fips),
      county_name_key = normalize_county_name_key(county_name)
    )
}

read_parcel_available_market_counties <- function(con) {
  market_counties <- read_market_county_membership(con)

  parcel_counties <- DBI::dbGetQuery(con, "
    SELECT DISTINCT
      upper(trim(state)) AS state_abbr,
      county_geoid,
      county_fips,
      county_name
    FROM rof_parcel.parcel_tabular_clean
    WHERE state IS NOT NULL
      AND county_name IS NOT NULL
  ") %>%
    as_tibble() %>%
    mutate(
      state_abbr = toupper(as.character(state_abbr)),
      county_geoid = as.character(county_geoid),
      county_fips = normalize_county_fips(county_fips),
      county_name_key = normalize_county_name_key(county_name)
    ) %>%
    distinct(state_abbr, county_geoid, county_fips, county_name_key)

  market_counties %>%
    semi_join(
      parcel_counties,
      by = c("state_abbr", "county_geoid", "county_fips", "county_name_key")
    ) %>%
    arrange(market_key, county_geoid)
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
      state_abbr = toupper(as.character(state)),
      county_fips = normalize_county_fips(dplyr::coalesce(county_fips, source_county_id)),
      county_code = normalize_county_code(county_fips),
      county_tag = dplyr::coalesce(as.character(county_tag), derive_county_tag(county_fips)),
      county_name_key = normalize_county_name_key(county_name)
    ) %>%
    semi_join(
      market_counties %>% select(state_abbr, county_name_key) %>% distinct(),
      by = c("state_abbr", "county_name_key")
    ) %>%
    arrange(
      dplyr::desc(load_completed_at),
      dplyr::desc(generated_at),
      dplyr::desc(ingest_run_id)
    ) %>%
    distinct(state_abbr, county_name_key, .keep_all = TRUE)
}

build_parcel_standardization_products <- function(con, parcel_root = resolve_parcel_standardized_root()) {
  market_counties <- read_parcel_available_market_counties(con)
  if (nrow(market_counties) == 0) {
    stop("Layer 04 found no parcel-backed market counties to publish.", call. = FALSE)
  }
  parcel_build <- build_parcels_canonical(con, market_counties = market_counties)
  land_use_mapping <- read_land_use_mapping(con)
  geometry_join_qa <- read_county_geometry_join_qa(parcel_root = parcel_root)
  load_log <- read_county_load_log(con, market_counties)
  parcels_canonical <- attach_retail_classification(parcel_build$canonical, land_use_mapping)
  parcel_lineage <- build_parcel_lineage(
    market_counties = market_counties,
    geometry_join_qa = geometry_join_qa,
    load_log = load_log,
    parcels_canonical = parcels_canonical
  )
  parcel_join_qa <- build_parcel_join_qa(parcel_lineage)
  retail_parcels <- build_retail_parcels(parcels_canonical)

  products <- list(
    market_counties = market_counties,
    land_use_mapping = land_use_mapping,
    parcels_canonical = parcels_canonical,
    parcel_uid_duplicates = parcel_build$duplicates,
    parcel_join_qa = parcel_join_qa,
    parcel_lineage = parcel_lineage,
    retail_parcels = retail_parcels
  )

  products$qa_unmapped_use_codes <- build_parcel_unmapped_use_codes(products$parcels_canonical, products$land_use_mapping)
  products$qa_validation_results <- build_parcel_validation_results(products)
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
