# serving.parcel_shortlist.R
# Purpose: Build serving.parcel_shortlist from SQL-managed logic
# Grain: one row per market_key, zone_system, parcel_uid
# Dependencies: serving.retail_parcel_tract_assignment, serving.retail_intensity_by_tract, parcel.parcels_canonical, zones.*

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
