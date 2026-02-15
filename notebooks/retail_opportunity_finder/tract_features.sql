-- tract_features.sql
-- Purpose: Produce tract-level feature spine for Retail Opportunity Finder V1 (no density yet).
-- Params:
--   {{cbsa_code}}   : e.g., '27260' Jacksonville, FL
--   {{target_year}} : e.g., 2024
-- Notes:
-- - Uses county-level BPS total_units with 3-year rolling average, assigned to tracts via county.
-- - Uses tract-level ACS-derived metrics from your existing silver/gold tables.


WITH
/* 1) Tract universe for the CBSA */
cbsa_counties AS (
  SELECT DISTINCT
    county_geoid,
    cbsa_code
  FROM metro_deep_dive.silver.xwalk_cbsa_county
  WHERE cbsa_code = '27260'
),
tract_universe AS (
  SELECT
    t.tract_geoid,
    printf('%02d%03d', CAST(t.state_fip AS INTEGER), CAST(t.county_fip AS INTEGER)) AS county_geoid,
    '27260' AS cbsa_code
  FROM metro_deep_dive.silver.xwalk_tract_county t
),
tracts AS (
  SELECT
    u.tract_geoid,
    u.county_geoid,
    u.cbsa_code
  FROM tract_universe u
  JOIN cbsa_counties c
    ON u.county_geoid = c.county_geoid
),

/* 2) County-level BPS, 3-year rolling avg of total_units */
bps_base AS (
  SELECT
    geo_id AS county_geoid,
    CAST(period AS INTEGER) AS year,
    CAST(total_units AS DOUBLE) AS total_units
  FROM metro_deep_dive.silver.bps_wide
  WHERE geo_level = 'County'
),

bps_cbsa AS (
  SELECT b.*
  FROM bps_base b
  JOIN cbsa_counties c
    ON b.county_geoid = c.county_geoid
),

bps_3yr AS (
  SELECT
    county_geoid,
    year,
    AVG(total_units) OVER (
      PARTITION BY county_geoid
      ORDER BY year
      ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS total_units_3yr_avg
  FROM bps_cbsa
),

/* 3) Tract metrics (population, housing, transport) */
pop AS (
  SELECT
    geo_id AS tract_geoid,
    year,
    CAST(pop_total AS DOUBLE) AS pop_total,
    CAST(pop_growth_5yr AS DOUBLE) AS pop_growth_5yr,
    CAST(pop_growth_3yr AS DOUBLE) AS pop_growth_3yr
  FROM metro_deep_dive.gold.population_demographics
  WHERE geo_level = 'tract'
  and year = 2024
),
housing AS (
  SELECT
    geo_id AS tract_geoid,
    year,
    CAST(median_gross_rent AS DOUBLE) AS median_gross_rent,
    CAST(median_home_value AS DOUBLE) AS median_home_value
  FROM metro_deep_dive.silver.housing_kpi
  WHERE geo_level = 'tract'
),
transport AS (
  SELECT
    geo_id AS tract_geoid,
    year,
    CAST(pct_commute_wfh AS DOUBLE) AS pct_commute_wfh,
    CAST(mean_travel_time AS DOUBLE) AS mean_travel_time
  FROM metro_deep_dive.silver.transport_kpi
  WHERE geo_level = 'tract'
),

geom as (
  SELECT
    tract_geoid,
    CAST(land_area_sqmi AS DOUBLE) AS land_area_sqmi
  FROM metro_deep_dive.geo.tracts_fl
),

/* 4) Assemble base feature rows for target year */
base AS (
  SELECT
    t.cbsa_code,
    t.county_geoid,
    t.tract_geoid,
    p.year,

    -- population
    p.pop_total,
    p.pop_growth_3yr,
    p.pop_growth_5yr,

    -- housing
    h.median_gross_rent,
    h.median_home_value,

    -- transport
    tr.pct_commute_wfh,
    tr.mean_travel_time,

    -- commute intensity (Option B)
    (tr.mean_travel_time * (1 - tr.pct_commute_wfh)) AS commute_intensity_b,

    -- housing supply via BPS (county-assigned)
    b.total_units_3yr_avg,
    CASE
      WHEN p.pop_total > 0 AND b.total_units_3yr_avg IS NOT NULL
        THEN 1000.0 * b.total_units_3yr_avg / p.pop_total
      ELSE NULL
    END AS units_per_1k_3yr,
    g.land_area_sqmi,
    CASE
      WHEN g.land_area_sqmi > 0 THEN p.pop_total / g.land_area_sqmi
      ELSE NULL
    END AS pop_density

  FROM tracts t
  JOIN pop p
    ON t.tract_geoid = p.tract_geoid
   AND p.year = 2024

  LEFT JOIN housing h
    ON t.tract_geoid = h.tract_geoid
   AND h.year = p.year

  LEFT JOIN transport tr
    ON t.tract_geoid = tr.tract_geoid
   AND tr.year = p.year

  LEFT JOIN bps_3yr b
    ON t.county_geoid = b.county_geoid
   AND b.year = p.year
   
  LEFT JOIN geom g 
  	ON t.tract_geoid = g.tract_geoid
)
,

/* 5) Percentiles computed on non-null values, joined back */
pop_pctl AS (
  SELECT
    tract_geoid,
    PERCENT_RANK() OVER (ORDER BY pop_growth_3yr) AS pop_growth_pctl
  FROM base
  WHERE pop_growth_3yr IS NOT NULL
),
rent_pctl AS (
  SELECT
    tract_geoid,
    PERCENT_RANK() OVER (ORDER BY median_gross_rent) AS rent_pctl
  FROM base
  WHERE median_gross_rent IS NOT NULL
),
value_pctl AS (
  SELECT
    tract_geoid,
    PERCENT_RANK() OVER (ORDER BY median_home_value) AS value_pctl
  FROM base
  WHERE median_home_value IS NOT NULL
),
density_pctl AS (
  SELECT
    tract_geoid,
    PERCENT_RANK() OVER (ORDER BY pop_density) AS density_pctl
  FROM base
  WHERE pop_density IS NOT NULL
),

pctl AS (
  SELECT
    b.*,
    pp.pop_growth_pctl,
    rp.rent_pctl,
    vp.value_pctl,
    dp.density_pctl
  FROM base b
  LEFT JOIN pop_pctl pp  USING (tract_geoid)
  LEFT JOIN rent_pctl rp USING (tract_geoid)
  LEFT JOIN value_pctl vp USING (tract_geoid)
  LEFT JOIN density_pctl dp USING (tract_geoid)
),

tract_features as (
SELECT
  cbsa_code,
  county_geoid,
  tract_geoid,
  year,

  pop_total,
  pop_growth_3yr,
  pop_growth_pctl,
  pop_growth_5yr,

  median_gross_rent,
  median_home_value,
  rent_pctl,
  value_pctl,

  CASE
  WHEN rent_pctl IS NOT NULL AND value_pctl IS NOT NULL THEN 0.5*rent_pctl + 0.5*value_pctl
  WHEN rent_pctl IS NULL AND value_pctl IS NOT NULL THEN value_pctl
  WHEN rent_pctl IS NOT NULL AND value_pctl IS NULL THEN rent_pctl
  ELSE NULL
END AS price_proxy_pctl,

  pct_commute_wfh,
  mean_travel_time,
  commute_intensity_b,

  total_units_3yr_avg,
  units_per_1k_3yr,  
  
  pop_density,
  land_area_sqmi,
  density_pctl,

  -- Gates we can compute without density
  CASE WHEN pop_growth_pctl >= 0.50 THEN 1 ELSE 0 END AS gate_pop,
  CASE WHEN (
  CASE
    WHEN rent_pctl IS NOT NULL AND value_pctl IS NOT NULL THEN 0.5*rent_pctl + 0.5*value_pctl
    WHEN rent_pctl IS NULL AND value_pctl IS NOT NULL THEN value_pctl
    WHEN rent_pctl IS NOT NULL AND value_pctl IS NULL THEN rent_pctl
    ELSE NULL
  END
) < 0.70 THEN 1 ELSE 0 END AS gate_price,
  CASE WHEN density_pctl <= 0.70 THEN 1 ELSE 0 END AS gate_density,
  CASE
      WHEN (CASE WHEN pop_growth_pctl >= 0.50 THEN 1 ELSE 0 END) = 1
       AND (CASE WHEN (
          CASE
            WHEN rent_pctl IS NOT NULL AND value_pctl IS NOT NULL THEN 0.5*rent_pctl + 0.5*value_pctl
            WHEN rent_pctl IS NULL AND value_pctl IS NOT NULL THEN value_pctl
            WHEN rent_pctl IS NOT NULL AND value_pctl IS NULL THEN rent_pctl
            ELSE NULL
          END
        ) < 0.70 THEN 1 ELSE 0 END) = 1
        AND (CASE WHEN density_pctl <= 0.70 THEN 1 ELSE 0 END) = 1
      THEN 1 ELSE 0
    END AS eligible_v1

FROM pctl
ORDER BY tract_geoid
)

select *
from tract_features

