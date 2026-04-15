-- Build sample line datasets from gold tables.
-- Creates a single long-form dataset using population and per-capita income.

WITH target_geos AS (
  SELECT '48900'::VARCHAR AS geo_id, TRUE AS highlight_flag UNION ALL
  SELECT '16740'::VARCHAR AS geo_id, FALSE AS highlight_flag UNION ALL
  SELECT '39580'::VARCHAR AS geo_id, FALSE AS highlight_flag
),
division_lookup AS (
  SELECT
    c.cbsa_code AS geo_id,
    s.census_division AS division,
    ROW_NUMBER() OVER (PARTITION BY c.cbsa_code ORDER BY c.county_geoid) AS rn
  FROM metro_deep_dive.silver.xwalk_cbsa_county c
  LEFT JOIN metro_deep_dive.silver.xwalk_state_region s
    ON c.state_fips = s.state_fips
),
division_dedup AS (
  SELECT geo_id, division
  FROM division_lookup
  WHERE rn = 1
),
population_series AS (
  SELECT
    p.geo_level,
    p.geo_id,
    p.geo_name,
    p.year AS period,
    'level'::VARCHAR AS time_window,
    'pop_total'::VARCHAR AS metric_id,
    'Population'::VARCHAR AS metric_label,
    p.pop_total::DOUBLE AS metric_value,
    'gold.population_demographics'::VARCHAR AS source,
    '2026-04-14'::VARCHAR AS vintage,
    d.division AS "group",
    g.highlight_flag,
    NULL::DOUBLE AS benchmark_value,
    NULL::INTEGER AS index_base_period,
    NULL::VARCHAR AS note
  FROM metro_deep_dive.gold.population_demographics p
  JOIN target_geos g
    ON p.geo_id = g.geo_id
  LEFT JOIN division_dedup d
    ON p.geo_id = d.geo_id
  WHERE p.geo_level = 'cbsa'
    AND p.year BETWEEN 2013 AND 2023
    AND p.pop_total IS NOT NULL
),
income_series AS (
  SELECT
    i.geo_level,
    i.geo_id,
    i.geo_name,
    i.year AS period,
    'level'::VARCHAR AS time_window,
    'calc_income_pc'::VARCHAR AS metric_id,
    'Per Capita Income'::VARCHAR AS metric_label,
    i.calc_income_pc::DOUBLE AS metric_value,
    'gold.economics_income_wide'::VARCHAR AS source,
    '2026-04-14'::VARCHAR AS vintage,
    d.division AS "group",
    g.highlight_flag,
    NULL::DOUBLE AS benchmark_value,
    NULL::INTEGER AS index_base_period,
    NULL::VARCHAR AS note
  FROM metro_deep_dive.gold.economics_income_wide i
  JOIN target_geos g
    ON i.geo_id = g.geo_id
  LEFT JOIN division_dedup d
    ON i.geo_id = d.geo_id
  WHERE i.geo_level = 'cbsa'
    AND i.year BETWEEN 2013 AND 2023
    AND i.calc_income_pc IS NOT NULL
)
SELECT *
FROM population_series
UNION ALL
SELECT *
FROM income_series
ORDER BY metric_id, geo_id, period;
