-- This script is used to calculate Industry metrics
-- We use BEA Industry GDP here, to simplify we only use Real GDP

-- We need to ensure that our Industry GDPs don't sum to more than the market total
create or replace table metro_deep_dive.gold.economics_industry_wide as 
with acs_base as ( 
select lower(geo_level) as geo_level,
	geo_id,
	geo_name,
	year, 
	pop_total
from metro_deep_dive.silver.age_kpi 
),

-- Real GDP
cagdp9 as (
select geo_level,
	geo_id,
	geo_name,
	period, 
	real_gdp_total,
	real_gdp_private,
	real_gdp_private / real_gdp_total as pct_real_gdp_private,
	real_gdp_gov_enterprises as real_gdp_gov,
	real_gdp_gov_enterprises / real_gdp_total as pct_real_gdp_gov,
	real_gdp_natural_resources_all as real_gdp_natural_resources, -- Ag and Mining
	real_gdp_natural_resources_all / real_gdp_total as pct_real_gdp_natural_resources,
	real_gdp_utilities,
	real_gdp_utilities / real_gdp_total as pct_real_gdp_utilities,
	real_gdp_transportation,
	real_gdp_transportation / real_gdp_total as pct_real_gdp_transportation,
	real_gdp_trade_all as real_gdp_trade, -- Retail and Wholesale trade
	real_gdp_trade_all / real_gdp_total as pct_real_gdp_trade,
	real_gdp_manufacturing_all as real_gdp_manufacturing, 
	real_gdp_manufacturing_all / real_gdp_total as pct_real_gdp_manufacturing,
	real_gdp_construction,
	real_gdp_construction / real_gdp_total as pct_real_gdp_construction,
	real_gdp_information,
	real_gdp_information / real_gdp_total as pct_real_gdp_information,
	real_gdp_finance_insurance + real_gdp_real_estate as real_gdp_fire, -- Finance, Insurance, Real Estate
	(real_gdp_finance_insurance + real_gdp_real_estate) / real_gdp_total as pct_real_gdp_fire,
	real_gdp_professional_scientific + real_gdp_professional_management + real_gdp_professional_admin_support as 
	real_gdp_professional, -- Science, Management, Admin Support
	(real_gdp_professional_scientific + real_gdp_professional_management + real_gdp_professional_admin_support) / real_gdp_total as 
	pct_real_gdp_professional,
	real_gdp_education_all as real_gdp_edu_health, -- Education and Health
	real_gdp_education_all / real_gdp_total as pct_real_gdp_edu_health,
	-- gdp_health,
	real_gdp_arts_entertainment + real_gdp_accomodation_food as
	real_gdp_leisure, -- Art, Entertainment, Accomidations, Food
	(real_gdp_arts_entertainment + real_gdp_accomodation_food) / real_gdp_total as pct_real_gdp_leisure,
	real_gdp_other,
	real_gdp_other / real_gdp_total as pct_real_gdp_total
from metro_deep_dive.silver.bea_regional_cagdp9_wide
)

select geo_level,
	geo_id,
	geo_name,
	period,
	real_gdp_total,
	-- Industries 
	real_gdp_natural_resources,
	real_gdp_manufacturing,
	real_gdp_construction,
	real_gdp_trade,
	real_gdp_transportation,
	real_gdp_information,
	real_gdp_fire,
	real_gdp_professional,
	real_gdp_edu_health,
	real_gdp_leisure,
	real_gdp_gov,
	
	(real_gdp_natural_resources + real_gdp_manufacturing + real_gdp_construction + real_gdp_trade +
	real_gdp_transportation + real_gdp_information + real_gdp_fire + real_gdp_professional + real_gdp_edu_health + 
	real_gdp_leisure + real_gdp_gov) as sector_sum,
	real_gdp_total - sector_sum as calc_real_gdp_other,
	
	-- Industries Rates
	pct_real_gdp_natural_resources,
	pct_real_gdp_manufacturing,
	pct_real_gdp_construction,
	pct_real_gdp_trade,
	pct_real_gdp_transportation,
	pct_real_gdp_information,
	pct_real_gdp_fire,
	pct_real_gdp_professional,
	pct_real_gdp_edu_health,
	pct_real_gdp_leisure,
	pct_real_gdp_gov,
	calc_real_gdp_other / real_gdp_total as pct_calc_real_gdp_other,
	
	-- HHI Index
	(
    POWER(pct_real_gdp_natural_resources, 2) +
    POWER(pct_real_gdp_manufacturing, 2) +
    POWER(pct_real_gdp_construction, 2) +
    POWER(pct_real_gdp_trade, 2) +
    POWER(pct_real_gdp_transportation, 2) +
    POWER(pct_real_gdp_information, 2) +
    POWER(pct_real_gdp_fire, 2) +
    POWER(pct_real_gdp_professional, 2) +
    POWER(pct_real_gdp_edu_health, 2) +
    POWER(pct_real_gdp_leisure, 2) +
    POWER(pct_real_gdp_gov, 2) +
    POWER(pct_calc_real_gdp_other, 2) 
    
  ) AS industry_concentration_hhi,
	
	-- Checks
	
	(real_gdp_natural_resources + real_gdp_manufacturing + real_gdp_construction + real_gdp_trade +
	real_gdp_transportation + real_gdp_information + real_gdp_fire + real_gdp_professional + real_gdp_edu_health + 
	real_gdp_leisure + real_gdp_gov) / real_gdp_total as sector_sum_ratio,
	case when sector_sum_ratio > 1.05 then 'Sector Bug' 
	else 'Non Bug' end as sector_sum_ratio_quality_flag
from cagdp9

;



-- View our metrics
select line_desc_clean , metric_key, naics_raw
from metro_deep_dive.silver.bea_regional_metrics_clean
where "table" = 'CAGDP9'

-- Debug our GDP ratios
select geo_level,
	geo_id,
	geo_name,
	period, 
	real_gdp_total,
	real_gdp_private,
	real_gdp_gov_enterprises,
	real_gdp_private_goods_producing_industries,
	real_gdp_private_services_providing_industries,
	real_gdp_private_goods_producing_industries + real_gdp_private_services_providing_industries as calc_private,
	(calc_private + real_gdp_gov_enterprises) / real_gdp_total as gdp_ratio,
	calc_private / real_gdp_total as private_gdp_ratio
from metro_deep_dive.silver.bea_regional_cagdp9_wide
where private_gdp_ratio > 1 and real_gdp_total > 0
order by gdp_ratio desc 