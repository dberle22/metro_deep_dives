-- serving.parcel_zone_overlay.sql
-- Purpose: Aggregate retail intensity and tract metrics by market zone (contiguity + cluster)
-- Grain: one row per market_key, cbsa_code, zone_system, zone_id
-- Notes: Uses zone membership tables and tract-level retail intensity.

CREATE OR REPLACE TABLE serving.parcel_zone_overlay AS 

WITH zone_assignments AS (
  SELECT
    c.market_key,
    mt.cbsa_code,
    c.tract_geoid,
    s.zone_id,
    s.zone_label,
    s.zone_order,
    s.mean_tract_score,
    'contiguity' AS zone_system
  FROM zones.contiguity_zone_components c
  LEFT JOIN zones.contiguity_zone_summary s
    ON c.market_key = s.market_key
    AND c.zone_component_id = s.zone_component_id
  LEFT JOIN foundation.market_tract_geometry mt
    ON c.tract_geoid = mt.tract_geoid
  UNION ALL
  SELECT
    a.market_key,
    mt.cbsa_code,
    a.tract_geoid,
    a.cluster_id AS zone_id,
    a.cluster_label AS zone_label,
    a.cluster_order AS zone_order,
    s.mean_tract_score,
    'cluster' AS zone_system
  FROM zones.cluster_assignments a
  LEFT JOIN zones.cluster_zone_summary s
    ON a.market_key = s.market_key
    AND a.cluster_id = s.cluster_id
  LEFT JOIN foundation.market_tract_geometry mt
    ON a.tract_geoid = mt.tract_geoid
),
zone_summaries AS (
  SELECT
    market_key,
    zone_system,
    zone_id,
    zone_label,
    zone_order,
    total_population,
    zone_area_sq_mi,
    mean_tract_score,
    percent_rank() OVER (PARTITION BY market_key ORDER BY mean_tract_score) AS zone_quality_score
  FROM (
    SELECT
      market_key,
      'contiguity' AS zone_system,
      zone_id,
      zone_label,
      zone_order,
      total_population,
      zone_area_sq_mi,
      mean_tract_score
    FROM zones.contiguity_zone_summary
    UNION ALL
    SELECT
      market_key,
      'cluster' AS zone_system,
      cluster_id AS zone_id,
      cluster_label AS zone_label,
      cluster_order AS zone_order,
      total_population,
      zone_area_sq_mi,
      mean_tract_score
    FROM zones.cluster_zone_summary
  ) zones_union
)
SELECT
  za.market_key,
  za.cbsa_code,
  za.zone_system,
  za.zone_id,
  za.zone_label,
  za.zone_order,
  COUNT(DISTINCT za.tract_geoid) AS tracts,
  zs.total_population,
  zs.zone_area_sq_mi,
  SUM(COALESCE(r.retail_parcel_count, 0)) AS retail_parcel_count,
  CAST(NULL AS DOUBLE) AS retail_area,
  SUM(COALESCE(r.tract_land_area_sqmi, 0)) AS tract_land_area_sqmi,
  CAST(NULL AS DOUBLE) AS retail_area_density,
  AVG(r.local_retail_context_score) AS local_retail_context_score,
  zs.mean_tract_score,
  zs.zone_quality_score
FROM zone_assignments za
LEFT JOIN serving.retail_intensity_by_tract r
  ON za.tract_geoid = r.tract_geoid
LEFT JOIN zone_summaries zs
  ON za.market_key = zs.market_key
  AND za.zone_system = zs.zone_system
  AND za.zone_id = zs.zone_id
GROUP BY
  za.market_key,
  za.cbsa_code,
  za.zone_system,
  za.zone_id,
  za.zone_label,
  za.zone_order,
  zs.total_population,
  zs.zone_area_sq_mi,
  zs.mean_tract_score,
  zs.zone_quality_score
ORDER BY za.zone_system, za.zone_order;
