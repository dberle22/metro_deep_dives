-- foundation.cbsa_features
-- Canonical SQL for the foundation layer's CBSA feature product.
-- Grain: one row per cbsa_code, year.

WITH cbsa AS (
  SELECT
    cbsa_code,
    cbsa_name,
    CASE
      WHEN LSAD = 'M1' THEN 'Metro Area'
      WHEN LSAD = 'M2' THEN 'Micro Area'
      ELSE NULL
    END AS cbsa_type,
    SPLIT_PART(TRIM(SPLIT_PART(cbsa_name, ',', 2)), '-', 1) AS primary_state_abbr,
    ALAND / 2589988.110336 AS land_area_sq_mi
  FROM metro_deep_dive.geo.cbsas
),

cbsa_metadata AS (
  -- Inner join intentionally drops CBSA rows whose derived primary state
  -- does not map cleanly into the state-region crosswalk.
  SELECT
    cbsa.cbsa_code,
    cbsa.cbsa_name,
    cbsa.cbsa_type,
    cbsa.primary_state_abbr,
    cbsa.land_area_sq_mi,
    xsr.state_fips,
    xsr.census_region,
    xsr.census_division
  FROM cbsa
  INNER JOIN metro_deep_dive.silver.xwalk_state_region xsr
    ON cbsa.primary_state_abbr = xsr.state_abbr
),

pop AS (
  SELECT
    geo_id AS cbsa_code,
    year,
    CAST(pop_total AS DOUBLE) AS pop_total,
    CAST(pop_growth_3yr AS DOUBLE) AS pop_growth_3yr,
    CAST(pop_growth_5yr AS DOUBLE) AS pop_growth_5yr
  FROM metro_deep_dive.gold.population_demographics
  WHERE geo_level = 'cbsa'
),

housing AS (
  SELECT
    geo_id AS cbsa_code,
    year,
    CAST(median_gross_rent AS DOUBLE) AS median_gross_rent,
    CAST(median_home_value AS DOUBLE) AS median_home_value
  FROM metro_deep_dive.silver.housing_kpi
  WHERE geo_level = 'cbsa'
),

transport AS (
  -- This currently relies on mean_travel_time from the transport KPI source.
  -- Source quality should be reviewed before locking this as a long-term contract.
  SELECT
    geo_id AS cbsa_code,
    year,
    CAST(pct_commute_wfh AS DOUBLE) AS pct_commute_wfh,
    CAST(mean_travel_time AS DOUBLE) AS mean_travel_time,
    CAST(mean_travel_time AS DOUBLE) * (1 - CAST(pct_commute_wfh AS DOUBLE)) AS commute_intensity_b
  FROM metro_deep_dive.silver.transport_kpi
  WHERE geo_level = 'cbsa'
),

bps AS (
  SELECT
    geo_id AS cbsa_code,
    CAST(period AS INTEGER) AS year,
    CAST(total_units AS DOUBLE) AS bps_total_units,
    AVG(total_units) OVER (
      PARTITION BY geo_id
      ORDER BY year
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS bps_units_3yr_avg
  FROM metro_deep_dive.silver.bps_wide
  WHERE geo_level = 'CBSA'
),

cbsa_metrics AS (
  SELECT
    meta.cbsa_code,
    meta.cbsa_name,
    meta.cbsa_type,
    meta.primary_state_abbr,
    meta.land_area_sq_mi,
    meta.state_fips,
    meta.census_region,
    meta.census_division,
    pop.year,
    pop.pop_total,
    pop.pop_growth_3yr,
    pop.pop_growth_5yr,
    housing.median_gross_rent,
    housing.median_home_value,
    transport.pct_commute_wfh,
    transport.mean_travel_time,
    transport.commute_intensity_b,
    bps.bps_total_units,
    CASE
      WHEN pop.pop_total > 0 AND bps.bps_total_units IS NOT NULL
        THEN 1000.0 * bps.bps_total_units / pop.pop_total
      ELSE NULL
    END AS bps_units_per_1k,
    bps.bps_units_3yr_avg,
    CASE
      WHEN pop.pop_total > 0 AND bps.bps_units_3yr_avg IS NOT NULL
        THEN 1000.0 * bps.bps_units_3yr_avg / pop.pop_total
      ELSE NULL
    END AS bps_units_per_1k_3yr_avg
  FROM cbsa_metadata meta
  LEFT JOIN pop
    ON meta.cbsa_code = pop.cbsa_code
  LEFT JOIN housing
    ON pop.cbsa_code = housing.cbsa_code
   AND pop.year = housing.year
  LEFT JOIN transport
    ON pop.cbsa_code = transport.cbsa_code
   AND pop.year = transport.year
  LEFT JOIN bps
    ON pop.cbsa_code = bps.cbsa_code
   AND pop.year = bps.year
)

SELECT
  cbsa_code,
  cbsa_name,
  cbsa_type,
  primary_state_abbr,
  land_area_sq_mi,
  state_fips,
  census_region,
  census_division,
  year,
  pop_total,
  ROW_NUMBER() OVER (PARTITION BY year, cbsa_type ORDER BY pop_total DESC) AS national_pop_rank,
  PERCENT_RANK() OVER (PARTITION BY year, cbsa_type ORDER BY pop_total) AS national_pop_pctl,
  ROW_NUMBER() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY pop_total DESC) AS region_pop_rank,
  PERCENT_RANK() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY pop_total) AS region_pop_pctl,
  pop_growth_3yr,
  ROW_NUMBER() OVER (PARTITION BY year, cbsa_type ORDER BY pop_growth_3yr DESC) AS national_pop_growth_3yr_rank,
  PERCENT_RANK() OVER (PARTITION BY year, cbsa_type ORDER BY pop_growth_3yr) AS national_pop_growth_3yr_pctl,
  ROW_NUMBER() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY pop_growth_3yr DESC) AS region_pop_growth_3yr_rank,
  PERCENT_RANK() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY pop_growth_3yr) AS region_pop_growth_3yr_pctl,
  pop_growth_5yr,
  ROW_NUMBER() OVER (PARTITION BY year, cbsa_type ORDER BY pop_growth_5yr DESC) AS national_pop_growth_5yr_rank,
  PERCENT_RANK() OVER (PARTITION BY year, cbsa_type ORDER BY pop_growth_5yr) AS national_pop_growth_5yr_pctl,
  ROW_NUMBER() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY pop_growth_5yr DESC) AS region_pop_growth_5yr_rank,
  PERCENT_RANK() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY pop_growth_5yr) AS region_pop_growth_5yr_pctl,
  median_gross_rent,
  ROW_NUMBER() OVER (PARTITION BY year, cbsa_type ORDER BY median_gross_rent DESC) AS national_gross_rent_rank,
  PERCENT_RANK() OVER (PARTITION BY year, cbsa_type ORDER BY median_gross_rent) AS national_gross_rent_pctl,
  ROW_NUMBER() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY median_gross_rent DESC) AS region_gross_rent_rank,
  PERCENT_RANK() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY median_gross_rent) AS region_gross_rent_pctl,
  median_home_value,
  ROW_NUMBER() OVER (PARTITION BY year, cbsa_type ORDER BY median_home_value DESC) AS national_home_value_rank,
  PERCENT_RANK() OVER (PARTITION BY year, cbsa_type ORDER BY median_home_value) AS national_home_value_pctl,
  ROW_NUMBER() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY median_home_value DESC) AS region_home_value_rank,
  PERCENT_RANK() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY median_home_value) AS region_home_value_pctl,
  pct_commute_wfh,
  ROW_NUMBER() OVER (PARTITION BY year, cbsa_type ORDER BY pct_commute_wfh DESC) AS national_wfh_rank,
  PERCENT_RANK() OVER (PARTITION BY year, cbsa_type ORDER BY pct_commute_wfh) AS national_wfh_pctl,
  ROW_NUMBER() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY pct_commute_wfh DESC) AS region_wfh_rank,
  PERCENT_RANK() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY pct_commute_wfh) AS region_wfh_pctl,
  mean_travel_time,
  ROW_NUMBER() OVER (PARTITION BY year, cbsa_type ORDER BY mean_travel_time) AS national_travel_time_rank,
  PERCENT_RANK() OVER (PARTITION BY year, cbsa_type ORDER BY mean_travel_time DESC) AS national_travel_time_pctl,
  ROW_NUMBER() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY mean_travel_time) AS region_travel_time_rank,
  PERCENT_RANK() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY mean_travel_time DESC) AS region_travel_time_pctl,
  commute_intensity_b,
  bps_total_units,
  bps_units_per_1k,
  bps_units_3yr_avg,
  bps_units_per_1k_3yr_avg,
  ROW_NUMBER() OVER (PARTITION BY year, cbsa_type ORDER BY bps_units_per_1k_3yr_avg DESC) AS national_units_1k_avg_rank,
  PERCENT_RANK() OVER (PARTITION BY year, cbsa_type ORDER BY bps_units_per_1k_3yr_avg) AS national_units_1k_avg_pctl,
  ROW_NUMBER() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY bps_units_per_1k_3yr_avg DESC) AS region_units_1k_avg_rank,
  PERCENT_RANK() OVER (PARTITION BY census_division, year, cbsa_type ORDER BY bps_units_per_1k_3yr_avg) AS region_units_1k_avg_pctl
FROM cbsa_metrics
