build_retail_parcels <- function(parcels_canonical_classified) {
  parcels_canonical_classified %>%
    filter(retail_flag) %>%
    arrange(county_geoid, parcel_uid)
}
