# Notebook-build Section 05 script
# Purpose: Read parcel/serving tables and emit Section 05 compatibility artifacts without fallback rebuilds.
#
# Manual run:
#   ROF_MARKET_KEY=jacksonville_fl Rscript notebooks/retail_opportunity_finder/notebook_build/sections/05_parcels/section_05_build.R
#
# Debug tip:
#   The main failure points in this notebook-build path have been:
#   1) preserving sf geometry when constructing `zones_canonical`
#   2) mixed CRS across county parcel geometry files
#   3) invalid parcel geometries inside county parcel geometry files
#   If this fails again, inspect `build_geometry_lookup()` in
#   `notebook_build/_shared/read_only_build_helpers.R` first.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()
source("notebooks/retail_opportunity_finder/notebook_build/_shared/read_only_build_helpers.R")

message("Running notebook_build section 05 build: 05_parcels")

profile <- get_market_profile()
con <- connect_project_duckdb(read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

assert_duckdb_tables(
  con,
  c(
    "parcel.parcels_canonical",
    "parcel.parcel_join_qa",
    "parcel.retail_parcels",
    "ref.land_use_mapping",
    "zones.cluster_zone_geometries",
    "serving.retail_parcel_tract_assignment",
    "serving.retail_intensity_by_tract",
    "serving.parcel_zone_overlay",
    "serving.parcel_shortlist"
  )
)

parcel_root <- resolve_parcel_standardized_root()

cluster_zones <- read_market_sf_table(
  con,
  "zones.cluster_zone_geometries",
  profile = profile,
  order_sql = "cluster_order"
) %>%
  drop_platform_metadata() %>%
  arrange(cluster_order)

# Keep the active sf geometry attached; using `transmute(..., geometry = geometry)`
# here can drop or mis-handle the geometry column in dplyr/sf pipelines.
zones_canonical <- cluster_zones %>%
  mutate(
    zone_system = "cluster",
    zone_id = as.character(cluster_id),
    zone_label = as.character(cluster_label)
  ) %>%
  select(zone_system, zone_id, zone_label) %>%
  sf::st_make_valid() %>%
  arrange(zone_id)

parcel_join_qa <- read_market_table(
  con,
  "parcel.parcel_join_qa",
  profile = profile,
  order_sql = "county_geoid"
)

geometry_bundle <- build_geometry_lookup(
  parcel_root = parcel_root,
  parcel_join_qa = parcel_join_qa,
  expected_epsg = GEOMETRY_ASSUMPTIONS$expected_crs_epsg
)

# If Jacksonville (or another market) fails below, the next thing to inspect is
# usually `geometry_bundle`: county parcel geometry inputs may have mixed CRS or
# invalid polygon topology that needs repair before parcel attach succeeds.

parcels_canonical_raw <- read_market_table(
  con,
  "parcel.parcels_canonical",
  profile = profile,
  order_sql = "county_geoid, parcel_uid"
)

retail_parcels_raw <- read_market_table(
  con,
  "parcel.retail_parcels",
  profile = profile,
  order_sql = "county_geoid, parcel_uid"
)

retail_mapping <- read_market_table(
  con,
  "ref.land_use_mapping",
  profile = profile,
  order_sql = "land_use_code"
) %>%
  distinct(land_use_code, .keep_all = TRUE)

retail_assignment <- read_market_table(
  con,
  "serving.retail_parcel_tract_assignment",
  profile = profile,
  order_sql = "tract_geoid, parcel_uid"
)

retail_intensity <- read_market_table(
  con,
  "serving.retail_intensity_by_tract",
  profile = profile,
  order_sql = "tract_geoid"
) %>%
  drop_platform_metadata()

parcel_zone_overlay <- read_market_table(
  con,
  "serving.parcel_zone_overlay",
  profile = profile,
  order_sql = "zone_system, zone_order"
)

parcel_shortlist <- read_market_table(
  con,
  "serving.parcel_shortlist",
  profile = profile,
  order_sql = "zone_system, shortlist_rank_system"
)

parcel_metric_lookup <- parcel_shortlist %>%
  select(parcel_uid, parcel_area_sqmi) %>%
  distinct(parcel_uid, .keep_all = TRUE)

parcels_canonical <- parcels_canonical_raw %>%
  mutate(
    parcel_uid = as.character(parcel_uid),
    parcel_id = as.character(parcel_id),
    join_key = trimws(as.character(join_key)),
    county = as.character(county_code),
    county_name = as.character(county_name),
    source_county_tag = as.character(source_county_tag),
    land_use_code = as.character(land_use_code),
    owner_name = as.character(owner_name),
    owner_addr = as.character(owner_addr),
    site_addr = as.character(site_addr),
    parcel_area_sqft = NA_real_,
    just_value = safe_numeric(just_value),
    assessed_value = dplyr::coalesce(
      if ("total_value" %in% names(parcels_canonical_raw)) safe_numeric(.data$total_value) else NA_real_,
      if ("land_value" %in% names(parcels_canonical_raw)) safe_numeric(.data$land_value) else NA_real_,
      if ("assessed_value" %in% names(parcels_canonical_raw)) safe_numeric(.data$assessed_value) else NA_real_
    ),
    last_sale_price = safe_numeric(last_sale_price),
    last_sale_date = as.Date(last_sale_date),
    qa_missing_join_key = as.logical(qa_missing_join_key),
    qa_zero_county = as.logical(qa_zero_county),
    source_mode = "duckdb_parcels_canonical"
  ) %>%
  select(
    parcel_uid,
    parcel_id,
    join_key,
    county,
    county_name,
    source_county_tag,
    land_use_code,
    owner_name,
    owner_addr,
    site_addr,
    parcel_area_sqft,
    just_value,
    assessed_value,
    last_sale_date,
    last_sale_price,
    qa_missing_join_key,
    qa_zero_county,
    source_mode
  ) %>%
  filter(!is.na(join_key), join_key != "", !is.na(county), county != "")

retail_lookup <- retail_parcels_raw %>%
  transmute(
    parcel_uid = as.character(parcel_uid),
    use_code_definition = as.character(land_use_description),
    use_code_type = as.character(land_use_category),
    retail_flag = as.logical(retail_flag),
    retail_subtype = dplyr::if_else(retail_flag & is.na(retail_subtype), "retail_uncategorized", as.character(retail_subtype)),
    review_note = as.character(review_note),
    parcel_segment = "Retail parcel"
  ) %>%
  distinct(parcel_uid, .keep_all = TRUE)

retail_classified_parcels_tabular <- parcels_canonical %>%
  left_join(retail_lookup, by = "parcel_uid") %>%
  left_join(
    retail_mapping %>%
      transmute(
        land_use_code = as.character(land_use_code),
        mapped_definition = as.character(description),
        mapped_type = as.character(category),
        mapped_review_note = as.character(review_note)
      ),
    by = "land_use_code"
  ) %>%
  left_join(parcel_metric_lookup, by = "parcel_uid") %>%
  mutate(
    use_code_definition = dplyr::coalesce(use_code_definition, mapped_definition),
    use_code_type = dplyr::coalesce(use_code_type, mapped_type),
    review_note = dplyr::coalesce(review_note, mapped_review_note),
    retail_flag = dplyr::coalesce(retail_flag, FALSE),
    retail_subtype = dplyr::if_else(retail_flag & is.na(retail_subtype), "retail_uncategorized", retail_subtype),
    parcel_segment = dplyr::if_else(retail_flag, "Retail parcel", "Residential/other parcel"),
    parcel_area_sqmi = safe_numeric(parcel_area_sqmi)
  ) %>%
  select(-mapped_definition, -mapped_type, -mapped_review_note)

retail_geometry_bundle <- attach_geometry(
  retail_classified_parcels_tabular,
  geometry_bundle$geometry_lookup,
  "section_05_retail_classified_parcels",
  GEOMETRY_ASSUMPTIONS$expected_crs_epsg
)
retail_classified_parcels <- retail_geometry_bundle$data

zone_overlay_cluster <- parcel_zone_overlay %>%
  filter(zone_system == "cluster") %>%
  drop_platform_metadata() %>%
  arrange(zone_order)

shortlist_geometry_bundle <- attach_geometry(
  parcel_shortlist %>%
    filter(zone_system == "cluster") %>%
    drop_platform_metadata() %>%
    enrich_shortlist_metrics(),
  geometry_bundle$geometry_lookup,
  "section_05_parcel_shortlist_cluster",
  GEOMETRY_ASSUMPTIONS$expected_crs_epsg
)
parcel_shortlist_cluster <- shortlist_geometry_bundle$data

readiness_report <- list(
  run_metadata = run_metadata(),
  source_modes = list(
    parcels_canonical = "duckdb_parcels_canonical",
    retail_parcels = "duckdb_retail_parcels",
    retail_assignment = "duckdb_serving_assignment",
    retail_intensity = "duckdb_serving_intensity",
    parcel_zone_overlay = "duckdb_serving_overlay",
    parcel_shortlist = "duckdb_serving_shortlist"
  ),
  input_files = list(
    parcel_root = parcel_root,
    parcel_geometry_files = geometry_bundle$parcel_geometry_paths
  ),
  schema_checks = list(
    zones_canonical = validate_columns(
      sf::st_drop_geometry(zones_canonical),
      c("zone_system", "zone_id", "zone_label"),
      "section_05_zones_canonical"
    ),
    parcels_canonical = validate_columns(
      parcels_canonical,
      c("parcel_uid", "join_key", "county", "land_use_code", "assessed_value", "source_mode"),
      "section_05_parcels_canonical"
    ),
    parcel_schema_check = geometry_bundle$parcel_schema_check
  ),
  key_checks = list(
    zones_canonical = list(
      dataset = "section_05_zones_canonical",
      key = "zone_system + zone_id",
      n_rows = nrow(zones_canonical),
      n_distinct = dplyr::n_distinct(paste(zones_canonical$zone_system, zones_canonical$zone_id, sep = "::")),
      duplicates = nrow(zones_canonical) - dplyr::n_distinct(paste(zones_canonical$zone_system, zones_canonical$zone_id, sep = "::")),
      pass = nrow(zones_canonical) == dplyr::n_distinct(paste(zones_canonical$zone_system, zones_canonical$zone_id, sep = "::"))
    ),
    parcels_canonical = validate_unique_key(parcels_canonical, "parcel_uid", "section_05_parcels_canonical")
  ),
  geometry_checks = list(
    zones_canonical = validate_sf(zones_canonical, "section_05_zones_canonical", GEOMETRY_ASSUMPTIONS$expected_crs_epsg),
    parcel_geom_check = geometry_bundle$parcel_geom_check
  ),
  counts = list(
    zones_canonical = nrow(zones_canonical),
    parcels_canonical = nrow(parcels_canonical),
    retail_assignment = nrow(retail_assignment),
    retail_intensity = nrow(retail_intensity),
    zone_overlay_cluster = nrow(zone_overlay_cluster),
    parcel_shortlist_cluster = nrow(parcel_shortlist_cluster)
  ),
  null_summary = null_rate_summary(
    parcels_canonical,
    c("parcel_area_sqft", "assessed_value", "last_sale_date", "last_sale_price", "land_use_code"),
    "section_05_parcels_canonical"
  ),
  pass = TRUE
)

retail_intensity_report <- list(
  run_metadata = run_metadata(),
  source_modes = list(
    retail_assignment = "duckdb_serving_assignment",
    retail_intensity = "duckdb_serving_intensity"
  ),
  checks = list(
    retail_classified_geom_check = retail_geometry_bundle$geometry_check
  ),
  counts = list(
    parcels_total = nrow(parcels_canonical),
    parcels_retail_flagged = sum(retail_classified_parcels$retail_flag, na.rm = TRUE),
    parcels_retail_assigned_to_tract = sum(retail_assignment$assignment_status == "assigned", na.rm = TRUE),
    parcels_retail_unassigned = sum(retail_assignment$assignment_status != "assigned", na.rm = TRUE),
    tracts_total = nrow(retail_intensity),
    tracts_with_retail = sum(retail_intensity$retail_parcel_count > 0, na.rm = TRUE),
    retail_classified_missing_geometry = retail_geometry_bundle$missing_geometry
  ),
  pass = TRUE
)

shortlist_report <- list(
  run_metadata = run_metadata(),
  source_modes = list(
    parcel_zone_overlay = "duckdb_serving_overlay",
    parcel_shortlist = "duckdb_serving_shortlist"
  ),
  checks = list(
    shortlist_geom_check = shortlist_geometry_bundle$geometry_check
  ),
  counts = list(
    overlay_cluster_zones = nrow(zone_overlay_cluster),
    parcel_zone_assignments_cluster = nrow(parcel_shortlist_cluster),
    shortlist_cluster_rows = nrow(parcel_shortlist_cluster),
    shortlist_missing_geometry_cluster = shortlist_geometry_bundle$missing_geometry,
    shortlist_zero_or_negative_just_value_count = sum(is.na(parcel_shortlist_cluster$just_value_clean), na.rm = TRUE),
    shortlist_small_area_excluded_from_value_psf_count = sum(is.na(parcel_shortlist_cluster$parcel_area_sqft_clean), na.rm = TRUE),
    shortlist_missing_value_psf_count = sum(is.na(parcel_shortlist_cluster$assessed_value_psf), na.rm = TRUE),
    shortlist_winsorized_low_count = sum(
      !is.na(parcel_shortlist_cluster$assessed_value_psf) &
        !is.na(parcel_shortlist_cluster$assessed_value_psf_winsorized) &
        parcel_shortlist_cluster$assessed_value_psf_winsorized < parcel_shortlist_cluster$assessed_value_psf
    ),
    shortlist_winsorized_high_count = sum(
      !is.na(parcel_shortlist_cluster$assessed_value_psf) &
        !is.na(parcel_shortlist_cluster$assessed_value_psf_winsorized) &
        parcel_shortlist_cluster$assessed_value_psf_winsorized > parcel_shortlist_cluster$assessed_value_psf
    )
  ),
  pass = TRUE
)

save_artifact(
  zones_canonical,
  resolve_output_path("05_parcels", "section_05_zones_canonical")
)
save_artifact(
  parcels_canonical,
  resolve_output_path("05_parcels", "section_05_parcels_canonical")
)
save_artifact(
  readiness_report,
  resolve_output_path("05_parcels", "section_05_input_readiness_report")
)
save_artifact(
  retail_classified_parcels,
  resolve_output_path("05_parcels", "section_05_retail_classified_parcels")
)
save_artifact(
  retail_intensity,
  resolve_output_path("05_parcels", "section_05_retail_intensity")
)
save_artifact(
  retail_intensity_report,
  resolve_output_path("05_parcels", "section_05_retail_intensity_report")
)
save_artifact(
  zone_overlay_cluster,
  resolve_output_path("05_parcels", "section_05_zone_overlay_cluster")
)
save_artifact(
  parcel_shortlist_cluster,
  resolve_output_path("05_parcels", "section_05_parcel_shortlist_cluster")
)
save_artifact(
  shortlist_report,
  resolve_output_path("05_parcels", "section_05_shortlist_report")
)

message("Notebook-build Section 05 compatibility artifacts complete.")
