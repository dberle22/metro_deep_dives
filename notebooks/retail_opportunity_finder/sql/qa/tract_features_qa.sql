
/*-- Validations

	-- Number of tracts in Base, should match the next validations
		-- Jax = 340
select count(distinct tract_geoid) 
from tracts

	--- Same number of tracts and rows
select COUNT(*) as n_rows, 
COUNT(DISTINCT tract_geoid) as n_tracts
FROM tract_features*/

-- Null rate for land area + density
SELECT
  AVG(CASE WHEN land_area_sqmi IS NULL THEN 1 ELSE 0 END) AS pct_land_area_null,
  AVG(CASE WHEN pop_density IS NULL THEN 1 ELSE 0 END) AS pct_density_null
FROM tract_features

-- Eligibility Counts
select eligible_v1,
	count(*) as tracts
from tract_features
group by all

-- check null rates
SELECT
  AVG(CASE WHEN median_gross_rent IS NULL THEN 1 ELSE 0 END) AS pct_rent_null,
  AVG(CASE WHEN median_home_value IS NULL THEN 1 ELSE 0 END) AS pct_value_null,
  AVG(CASE WHEN pct_commute_wfh IS NULL THEN 1 ELSE 0 END) AS pct_wfh_null,
  AVG(CASE WHEN total_units_3yr_avg IS NULL THEN 1 ELSE 0 END) AS pct_bps_null
FROM tract_features

-- Look at densest tracts to ensure pctl behaves
SELECT tract_geoid, pop_total, land_area_sqmi, pop_density, density_pctl
FROM tract_features
ORDER BY pop_density DESC
LIMIT 20;
