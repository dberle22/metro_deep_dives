-- Build qa.parcel_unmapped_use_codes
-- Migrated from R: tables/qa.parcel_unmapped_use_codes.R

SELECT
  pc.land_use_code,
  COUNT(*) AS parcel_count,
  'parcel.parcels_canonical anti-join ref.land_use_mapping' AS build_source,
  CAST(NOW() AS VARCHAR) AS run_timestamp
FROM parcel.parcels_canonical pc
WHERE pc.land_use_code IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM ref.land_use_mapping lum
    WHERE LPAD(TRIM(CAST(lum.land_use_code AS VARCHAR)), 3, '0') = pc.land_use_code
  )
GROUP BY pc.land_use_code
ORDER BY parcel_count DESC;
