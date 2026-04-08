# serving.retail_parcel_tract_assignment.R
# Purpose: Build serving.retail_parcel_tract_assignment from SQL-managed logic
# Grain: one row per market_key, parcel_uid
# Dependencies: parcel.parcels_canonical (retail_flag = TRUE), foundation.market_tract_geometry

build_retail_parcel_tract_assignment <- function(con, retail_parcels_sf, profile = get_market_profile()) {
  retail_parcels_tbl <- retail_parcels_sf %>%
    {
      if (inherits(., "sf")) sf::st_drop_geometry(.) else as_tibble(.)
    } %>%
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

  DBI::dbWriteTable(con, "tmp_retail_parcels", retail_parcels_tbl, temporary = TRUE, overwrite = TRUE)

  retail_parcel_tract_assignment <- query_market_serving_sql(
    con,
    "serving.retail_parcel_tract_assignment",
    list(retail_parcels_table = "tmp_retail_parcels")
  )

  retail_parcel_tract_assignment %>%
    mutate(
      build_source = "data_platform/layers/05_market_serving_prep/tables/serving.retail_parcel_tract_assignment.sql",
      run_timestamp = as.character(Sys.time())
    )
}
