-- foundation.market_county_geometry.sql
-- Purpose: Publish county geometry in DuckDB-friendly WKT form for all CBSA-linked counties.
-- Grain: one row per cbsa_code, county_geoid.

WITH county_cbsa AS (
  SELECT DISTINCT
    county_geoid,
    cbsa_code
  FROM metro_deep_dive.silver.xwalk_cbsa_county
)
SELECT
  cc.cbsa_code,
  c.county_geoid,
  c.county_name,
  c.state_fips,
  ST_AsText(c.geom) AS geom_wkt
FROM metro_deep_dive.geo.counties c
INNER JOIN county_cbsa cc
  ON c.county_geoid = cc.county_geoid
ORDER BY cc.cbsa_code, c.county_geoid
