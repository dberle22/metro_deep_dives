-- Build sample line datasets from DuckDB tables.
-- Assumes `overview_cbsa_constant_long` includes at least:
-- cbsa_geoid, cbsa_name, year, population, division, source fields as available.

-- 1) Base level series (population)
CREATE OR REPLACE TABLE visual_sample_line_level AS
SELECT
  'cbsa' AS geo_level,
  CAST(cbsa_geoid AS VARCHAR) AS geo_id,
  cbsa_name AS geo_name,
  CAST(year AS INTEGER) AS period,
  'level' AS time_window,
  'population' AS metric_id,
  'Population' AS metric_label,
  CAST(population AS DOUBLE) AS metric_value,
  'overview_cbsa_constant_long' AS source,
  '2026-03-02' AS vintage,
  division AS "group",
  CASE WHEN CAST(cbsa_geoid AS VARCHAR) = '48900' THEN TRUE ELSE FALSE END AS highlight_flag,
  NULL::DOUBLE AS benchmark_value,
  NULL::INTEGER AS index_base_period,
  NULL::VARCHAR AS note
FROM overview_cbsa_constant_long
WHERE year BETWEEN 2013 AND 2023;

-- 2) Optional second metric for indexed example if `inc_pc` exists in source.
--    If your table uses a different column name, replace `inc_pc` below.
CREATE OR REPLACE TABLE visual_sample_line_income AS
SELECT
  'cbsa' AS geo_level,
  CAST(cbsa_geoid AS VARCHAR) AS geo_id,
  cbsa_name AS geo_name,
  CAST(year AS INTEGER) AS period,
  'level' AS time_window,
  'inc_pc' AS metric_id,
  'Income Per Capita' AS metric_label,
  CAST(inc_pc AS DOUBLE) AS metric_value,
  'overview_cbsa_constant_long' AS source,
  '2026-03-02' AS vintage,
  division AS "group",
  CASE WHEN CAST(cbsa_geoid AS VARCHAR) = '48900' THEN TRUE ELSE FALSE END AS highlight_flag,
  NULL::DOUBLE AS benchmark_value,
  NULL::INTEGER AS index_base_period,
  NULL::VARCHAR AS note
FROM overview_cbsa_constant_long
WHERE year BETWEEN 2013 AND 2023
  AND inc_pc IS NOT NULL;

-- 3) Combined dataset for line chart testing.
CREATE OR REPLACE TABLE visual_sample_line AS
SELECT * FROM visual_sample_line_level
UNION ALL
SELECT * FROM visual_sample_line_income;

SELECT * FROM visual_sample_line ORDER BY metric_id, geo_id, period LIMIT 100;
