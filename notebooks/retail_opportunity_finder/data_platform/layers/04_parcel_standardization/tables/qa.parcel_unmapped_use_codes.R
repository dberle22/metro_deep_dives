build_parcel_unmapped_use_codes <- function(parcels_canonical, land_use_mapping) {
  parcels_canonical %>%
    filter(!is.na(land_use_code)) %>%
    anti_join(land_use_mapping %>% select(land_use_code), by = "land_use_code") %>%
    count(land_use_code, sort = TRUE, name = "parcel_count") %>%
    mutate(
      build_source = "parcel.parcels_canonical anti-join ref.land_use_mapping",
      run_timestamp = as.character(Sys.time())
    )
}
