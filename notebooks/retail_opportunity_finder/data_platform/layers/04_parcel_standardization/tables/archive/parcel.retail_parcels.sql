-- Build parcel.retail_parcels (archive)
-- DEPRECATED: Retail classification is now included in parcel.parcels_canonical
-- This table is maintained for backward compatibility only
-- Migrated from R: tables/archive/parcel.retail_parcels.R
-- This is a filtered subset of parcel.parcels_canonical where retail_flag = true

SELECT *
FROM parcel.parcels_canonical
WHERE retail_flag = TRUE
ORDER BY county_geoid, parcel_uid;
