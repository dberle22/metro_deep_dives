-- serving.retail_parcel_tract_assignment.sql
-- Purpose: Assign retail parcels to census tracts using normalized tract-prefix matching
-- Grain: one row per market_key, parcel_uid
-- Notes: Uses the first 11 digits of census_block_id when present and validates against market tract geometry.

CREATE OR REPLACE TABLE serving.retail_parcel_tract_assignment AS 

WITH retail_attrs AS (
  SELECT
    *,
    regexp_replace(COALESCE(CAST(census_block_id AS VARCHAR), ''), '[^0-9]', '', 'g') AS census_block_digits
  FROM parcel.retail_parcels
),
tract_valid AS (
  SELECT DISTINCT
    cbsa_code,
    tract_geoid
  FROM foundation.market_tract_geometry
),
assigned_from_prefix AS (
  SELECT
    ra.parcel_uid,
    CASE
      WHEN length(ra.census_block_digits) >= 11 THEN substr(ra.census_block_digits, 1, 11)
      ELSE NULL
    END AS tract_geoid_candidate,
    tv.tract_geoid AS tract_geoid_assigned
  FROM retail_attrs ra
  LEFT JOIN tract_valid tv
    ON ra.cbsa_code = tv.cbsa_code
    AND CASE
      WHEN length(ra.census_block_digits) >= 11 THEN substr(ra.census_block_digits, 1, 11)
      ELSE NULL
    END = tv.tract_geoid
)
SELECT
  ra.market_key,
  ra.cbsa_code,
  ra.state_abbr,
  ra.state_fips,
  ra.county_fips,
  ra.county_geoid,
  ra.county_code,
  ra.county_tag,
  ra.county_name,
  ra.parcel_uid,
  ra.parcel_id,
  ra.join_key,
  ra.land_use_code,
  ra.retail_subtype,
  -- ra.parcel_area_sqmi,
  ra.just_value,
  ra.land_value,
  ra.impro_value,
  ra.total_value,
  -- ra.assessed_value,
  ra.last_sale_date,
  ra.last_sale_price,
  ap.tract_geoid_assigned AS tract_geoid,
  CASE
    WHEN ap.tract_geoid_assigned IS NOT NULL THEN 'normalized_tract_prefix'
    ELSE 'unassigned'
  END AS assignment_method,
  CASE
    WHEN ap.tract_geoid_assigned IS NOT NULL THEN 'assigned'
    ELSE 'unassigned'
  END AS assignment_status
FROM retail_attrs ra
LEFT JOIN assigned_from_prefix ap
  ON ra.parcel_uid = ap.parcel_uid
ORDER BY ra.market_key, ra.county_geoid, ra.parcel_uid;
