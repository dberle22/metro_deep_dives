-- tract_universe.sql
-- Purpose: return tract universe for a CBSA (tracts that fall within CBSA counties)
-- Params:
--   {{cbsa_code}} : e.g., '27260' for Jacksonville, FL

WITH cbsa_counties AS (
  SELECT DISTINCT
    county_geoid,
    cbsa_code
  FROM metro_deep_dive.silver.xwalk_cbsa_county
  WHERE cbsa_code = '27260'  -- '{{cbsa_code}}'
),

tracts AS (
  SELECT
    tract_geoid,
    printf('%02d%03d', CAST(state_fip AS INTEGER), CAST(county_fip AS INTEGER)) AS county_geoid
  FROM metro_deep_dive.silver.xwalk_tract_county
),

tracts_final as (
SELECT
  t.tract_geoid,
  t.county_geoid,
  c.cbsa_code
FROM tracts t
JOIN cbsa_counties c
  ON t.county_geoid = c.county_geoid
ORDER BY t.tract_geoid
)

select tract_geoid,
	county_geoid,
	cbsa_code
from tracts_final


-- Tests below
/*
SELECT COUNT(*) AS n_tracts, COUNT(DISTINCT county_geoid) AS n_counties
FROM tracts_final;
*/

/*SELECT county_geoid, COUNT(*) AS n_tracts
FROM tracts_final
GROUP BY 1
ORDER BY n_tracts DESC;*/