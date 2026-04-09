-- serving.retail_intensity_by_tract.sql
-- Purpose: Calculate retail parcel density and intensity metrics at the tract level
-- Grain: one row per market_key, cbsa_code, tract_geoid
-- Notes: Uses a parcel assignment table and foundation.tract_features land area to compute local retail context.

CREATE OR REPLACE TABLE serving.retail_intensity_by_tract AS 

WITH parcel_assignment AS (
  SELECT *
  FROM serving.retail_parcel_tract_assignment
),
market_tracts AS (
  SELECT DISTINCT market_key, cbsa_code, tract_geoid
  FROM parcel_assignment
),
tract_area AS (
  SELECT
    cbsa_code,
    tract_geoid,
    county_geoid,
    land_area_sqmi AS tract_land_area_sqmi
  FROM foundation.tract_features
  WHERE year = 2024
),
retail_by_tract AS (
  SELECT
    market_key,
    cbsa_code,
    tract_geoid,
    COUNT(DISTINCT parcel_uid) AS retail_parcel_count
  FROM parcel_assignment
  WHERE assignment_status = 'assigned'
    AND tract_geoid IS NOT NULL
  GROUP BY market_key, cbsa_code, tract_geoid
)
SELECT
  mt.market_key,
  mt.cbsa_code,
  ta.county_geoid,
  mt.tract_geoid,
  ta.tract_land_area_sqmi,
  COALESCE(r.retail_parcel_count, 0) AS retail_parcel_count,
  CAST(NULL AS DOUBLE) AS retail_area,
  CAST(NULL AS DOUBLE) AS retail_area_density,
  COALESCE(
    percent_rank() OVER (PARTITION BY mt.market_key ORDER BY COALESCE(r.retail_parcel_count, 0)),
    0.5
  ) AS pctl_tract_retail_parcel_count,
  0.5 AS pctl_tract_retail_area_density,
  0.5 * COALESCE(percent_rank() OVER (PARTITION BY mt.market_key ORDER BY COALESCE(r.retail_parcel_count, 0)), 0.5)
    + 0.5 * 0.5
    AS local_retail_context_score
FROM market_tracts mt
LEFT JOIN tract_area ta
  ON mt.cbsa_code = ta.cbsa_code
  AND mt.tract_geoid = ta.tract_geoid
LEFT JOIN retail_by_tract r
  ON mt.cbsa_code = r.cbsa_code
  AND mt.tract_geoid = r.tract_geoid
ORDER BY mt.tract_geoid;
