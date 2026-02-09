-- Housing KPIs
	-- ACS: Rent, Home Values, Occupancy Rates
	-- Zillow: Home Value Growth, Rent Growth
	-- BPS: Permits
	-- HUD: FMR, Rent Burdens


-- Let's start with a base from ACS

with acs_base as ( 
select lower(geo_level) as geo_level,
	geo_id,
	geo_name,
	year, 
	pop_total
from metro_deep_dive.silver.age_kpi 
)

-- ACS Housing
select lower(geo_level) as geo_level,
	geo_id,
	geo_name,
	year, 
	hu_total,
	occ_total,
	occ_occupied,
	vacancy_rate,
	owner_occ_rate,
	renter_occ_rate,
	median_gross_rent,
	median_gross_rent * 12 as yearly_rent,
	median_home_value,
	rent_burden_total, -- This is renter Occupied
	pct_rent_burden_30plus,
	pct_rent_burden_50plus,
	struct_total,
	pct_struct_1_unit,
	pct_struct_small_mf,
	pct_struct_mid_mf,
	pct_struct_large_mf,
	pct_struct_mobile,
	pct_struct_small_mf + pct_struct_mid_mf  + pct_struct_large_mf  as pct_struct_multi_fam
from metro_deep_dive.silver.housing_kpi 

-- Bring in ACS Income to get Rent and Home Value to Income


select *
from metro_deep_dive.gold.population_demographics pd 
where lower(geo_level) in ('county', 'state', 'region')
and year = '2023'
