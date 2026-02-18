-- Create our CBSA Features table
-- We will create a timeseries DF of our CBSAs that will be loaded into R for our CBSA Overview section
-- Our grain will include 1 row per CBSA per year
-- In R we will calculate benchmarks based on Division, Region, Target GEOs, etc

/* 1) CBSA Universe and Metadata
	- Get our list of CBSAs with relevant metdata including Region, Division, Primary State, Metro vs Micro, etc. */

-- Get our Primary State Abbrev, Calculate Land Area SQ Miles, and create cbsa_type flag

with cbsa as (
select cbsa_code, 
	cbsa_name, 
	CASE WHEN LSAD = 'M1' THEN 'Metro Area'
		 WHEN LSAD = 'M2' THEN 'Micro Area' 
		 ELSE NULL END AS cbsa_type,
	SPLIT_PART(TRIM(SPLIT_PART(cbsa_name, ',', 2)), '-', 1) AS primary_state_abbr,
	ALAND / 2589988.110336 as land_area_sq_mi
from metro_deep_dive.geo.cbsas 
),

-- PR metro areas are removed from the inner join
cbsa_metadata as (
select cbsa_code,
	cbsa_name,
	cbsa_type, 
	primary_state_abbr, 
	land_area_sq_mi,
	xsr.state_fips,
	xsr.census_region,
	xsr.census_division
from cbsa 
inner join metro_deep_dive.silver.xwalk_state_region xsr 
	on cbsa.primary_state_abbr = xsr.state_abbr
),

-- Metrics

-- Pop 
pop as (
  SELECT
    geo_id AS cbsa_code,
    year,
    CAST(pop_total AS DOUBLE) AS pop_total,
    CAST(pop_growth_3yr AS DOUBLE) AS pop_growth_3yr,
    CAST(pop_growth_5yr AS DOUBLE) AS pop_growth_5yr
  FROM metro_deep_dive.gold.population_demographics
  WHERE geo_level = 'cbsa'
),

-- Housing
housing AS (
  SELECT
    geo_id AS cbsa_code,
    year,
    CAST(median_gross_rent AS DOUBLE) AS median_gross_rent,
    CAST(median_home_value AS DOUBLE) AS median_home_value
  FROM metro_deep_dive.silver.housing_kpi
  WHERE geo_level = 'cbsa'
),

-- Transport
-- Travel Times look funky
	-- We actually are ingested total travel times. We need to fix our pipelines to get Mean Travel Times
transport AS (
  SELECT
    geo_id AS cbsa_code,
    year,
    CAST(pct_commute_wfh AS DOUBLE) AS pct_commute_wfh,
    CAST(mean_travel_time AS DOUBLE) AS mean_travel_time,
    (CAST(mean_travel_time AS DOUBLE) * (1 - CAST(pct_commute_wfh AS DOUBLE))) AS commute_intensity_b -- Why are we commuting this?
  FROM metro_deep_dive.silver.transport_kpi
  WHERE geo_level = 'cbsa'
),

-- BPS
-- We have CBSA level data already
bps as (
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

-- Metrics
cbsa_metrics as (
select meta.cbsa_code,
	meta.cbsa_name,
	cbsa_type, 
	primary_state_abbr, 
	land_area_sq_mi,
	state_fips,
	census_region,
	census_division,
	pop.year,
	pop_total,
	pop_growth_3yr,
	pop_growth_5yr,
	median_gross_rent,
	median_home_value,
	pct_commute_wfh,
	mean_travel_time,
	commute_intensity_b,
	bps_total_units,
	CASE
    WHEN pop_total > 0 AND bps_total_units IS NOT NULL
      THEN 1000.0 * bps_total_units / pop_total
    ELSE NULL
  	END AS bps_units_per_1k,
  	bps_units_3yr_avg,
  	CASE
    WHEN pop_total > 0 AND bps_units_3yr_avg IS NOT NULL
      THEN 1000.0 * bps_units_3yr_avg / pop_total
    ELSE NULL
  	END AS bps_units_per_1k_3yr_avg
from cbsa_metadata meta 
left join pop 
	on meta.cbsa_code = pop.cbsa_code
left join housing hou 
	on pop.cbsa_code = hou.cbsa_code
	and pop.year = hou.year
left join transport tra 
	on pop.cbsa_code = tra.cbsa_code
	and pop.year = tra.year
left join bps 
	on pop.cbsa_code = bps.cbsa_code
	and pop.year = bps.year
)

-- Calculate ranks
select cbsa_code,
	cbsa_name,
	cbsa_type, 
	primary_state_abbr, 
	land_area_sq_mi,
	state_fips,
	census_region,
	census_division,
	year,
	
	-- Population
	pop_total,
	row_number() over(partition by year, cbsa_type order by pop_total desc) as national_pop_rank,
	percent_rank() over (partition by year, cbsa_type order by pop_total) AS national_pop_pctl,
	row_number() over(partition by census_division, year, cbsa_type order by pop_total desc) as region_pop_rank,
	percent_rank() over (partition by census_division, year, cbsa_type order by pop_total) AS region_pop_pctl,
	pop_growth_3yr,
	row_number() over(partition by year, cbsa_type order by pop_growth_3yr desc) as national_pop_growth_3yr_rank,
	percent_rank() over (partition by year, cbsa_type order by pop_growth_3yr ) AS national_pop_growth_3yr_pctl,
	row_number() over(partition by census_division, year, cbsa_type order by pop_growth_3yr desc) as region_pop_growth_3yr_rank,
	percent_rank() over (partition by census_division, year, cbsa_type order by pop_growth_3yr ) AS region_pop_growth_3yr_pctl,
	pop_growth_5yr,
	row_number() over(partition by year, cbsa_type order by pop_growth_5yr desc) as national_pop_growth_5yr_rank,
	percent_rank() over (partition by year, cbsa_type order by pop_growth_5yr ) AS national_pop_growth_5yr_pctl,
	row_number() over(partition by census_division, year, cbsa_type order by pop_growth_5yr desc) as region_pop_growth_5yr_rank,
	percent_rank() over (partition by census_division, year, cbsa_type order by pop_growth_5yr ) AS region_pop_growth_5yr_pctl,
	
	-- Home Values 
	median_gross_rent,
	row_number() over(partition by year, cbsa_type order by median_gross_rent desc) as national_gross_rent_rank,
	percent_rank() over (partition by year, cbsa_type order by median_gross_rent ) AS national_gross_rent_pctl,
	row_number() over(partition by census_division, year, cbsa_type order by median_gross_rent desc) as region_gross_rent_rank,
	percent_rank() over (partition by census_division, year, cbsa_type order by median_gross_rent ) AS region_gross_rent_pctl,
	median_home_value,
	row_number() over(partition by year, cbsa_type order by median_home_value desc) as national_home_value_rank,
	percent_rank() over (partition by year, cbsa_type order by median_home_value ) AS national_home_value_pctl,
	row_number() over(partition by census_division, year, cbsa_type order by median_home_value desc) as region_home_value_rank,
	percent_rank() over (partition by census_division, year, cbsa_type order by median_home_value ) AS region_home_value_pctl,
	
	-- Commute
	pct_commute_wfh,
	row_number() over(partition by year, cbsa_type order by pct_commute_wfh desc) as national_wfh_rank,
	percent_rank() over (partition by year, cbsa_type order by pct_commute_wfh ) AS national_wfh_pctl,
	row_number() over(partition by census_division, year, cbsa_type order by pct_commute_wfh desc) as region_wfh_rank,
	percent_rank() over (partition by census_division, year, cbsa_type order by pct_commute_wfh ) AS region_wfh_pctl,
	mean_travel_time,
	row_number() over(partition by year, cbsa_type order by mean_travel_time) as national_travel_time_rank,
	percent_rank() over (partition by year, cbsa_type order by mean_travel_time desc) AS national_travel_time_pctl,
	row_number() over(partition by census_division, year, cbsa_type order by mean_travel_time) as region_travel_time_rank,
	percent_rank() over (partition by census_division, year, cbsa_type order by mean_travel_time desc) AS region_travel_time_pctl,
	commute_intensity_b,
	
	-- BPS
	bps_total_units,
	bps_units_per_1k,
  	bps_units_3yr_avg,
  	bps_units_per_1k_3yr_avg,
	row_number() over(partition by year, cbsa_type order by bps_units_per_1k_3yr_avg desc) as national_units_1k_avg_rank,
	percent_rank() over (partition by year, cbsa_type order by bps_units_per_1k_3yr_avg ) AS national_units_1k_avg_pctl,
	row_number() over(partition by census_division, year, cbsa_type order by bps_units_per_1k_3yr_avg desc) as region_units_1k_avg_rank,
	percent_rank() over (partition by census_division, year, cbsa_type order by bps_units_per_1k_3yr_avg ) AS region_units_1k_avg_pctl
from cbsa_metrics 
