-- foundation.market_tract_geometry.sql
-- Purpose: Publish tract geometry in DuckDB-friendly WKT form for all CBSA-linked
-- tracts available in the upstream tract backbone.
-- Grain: one row per cbsa_code, tract_geoid.
-- Notes:
-- - Current compatibility source is metro_deep_dive.geo.tracts_supported_states.
-- - Target source is metro_deep_dive.geo.tracts_all_us once the upstream ETL is rebuilt.

WITH tract_cbsa AS (
  SELECT DISTINCT
    t.tract_geoid,
    printf('%02d%03d', CAST(t.state_fip AS INTEGER), CAST(t.county_fip AS INTEGER)) AS county_geoid,
    c.cbsa_code
  FROM metro_deep_dive.silver.xwalk_tract_county t
  INNER JOIN metro_deep_dive.silver.xwalk_cbsa_county c
    ON printf('%02d%03d', CAST(t.state_fip AS INTEGER), CAST(t.county_fip AS INTEGER)) = c.county_geoid
),
tract_geom AS (
  SELECT
    tract_geoid,
    county_geoid,
    state_fips,
    geom
    -- Compatibility source during the transition to metro_deep_dive.geo.tracts_all_us.
  FROM metro_deep_dive.geo.tracts_supported_states
)
SELECT
  tc.cbsa_code,
  tg.county_geoid,
  tg.tract_geoid,
  tg.state_fips,
  ST_AsText(tg.geom) AS geom_wkt
FROM tract_cbsa tc
INNER JOIN tract_geom tg
  ON tc.tract_geoid = tg.tract_geoid
ORDER BY tc.cbsa_code, tg.tract_geoid
