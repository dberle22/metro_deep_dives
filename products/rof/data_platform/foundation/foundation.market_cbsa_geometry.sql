-- foundation.market_cbsa_geometry.sql
-- Purpose: Publish CBSA geometry in DuckDB-friendly WKT form for all CBSAs.
-- Grain: one row per cbsa_code.

SELECT
  cbsa_code,
  cbsa_name,
  ST_AsText(geom) AS geom_wkt
FROM metro_deep_dive.geo.cbsas
ORDER BY cbsa_code
