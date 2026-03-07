# Data Dictionary: staging ACS Labor Group

## Overview
- Schema: `staging`
- Group: `ACS Labor`
- Tables in group: 11
- Row count range across tables: 13 to 433,172

## Tables
- `acs_labor_county`
- `acs_labor_division`
- `acs_labor_place`
- `acs_labor_region`
- `acs_labor_state`
- `acs_labor_tract_fl`
- `acs_labor_tract_ga`
- `acs_labor_tract_nc`
- `acs_labor_tract_sc`
- `acs_labor_us`
- `acs_labor_zcta`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 91
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `GEOID`, `year`, `NAME`, `pop_16plusE`, `pop_16plusM`, `in_labor_forceE`, `in_labor_forceM`, `in_lf_civilianE`, `in_lf_civilianM`, `in_lf_armed_forcesE`, `in_lf_armed_forcesM`, `not_in_labor_forceE`, `not_in_labor_forceM`, `employedE`, `employedM`, `occ_totalE`, `occ_totalM`, `occ_male_mgmt_business_sci_artsE`, `occ_male_mgmt_business_sci_artsM`, `occ_male_serviceE`, `occ_male_serviceM`, `occ_male_sales_officeE`, `occ_male_sales_officeM`, `occ_male_nat_resources_const_maintE`, `occ_male_nat_resources_const_maintM`, `occ_male_prod_transp_materialE`, `occ_male_prod_transp_materialM`, `occ_female_mgmt_business_sci_artsE`, `occ_female_mgmt_business_sci_artsM`, `occ_female_serviceE`, `occ_female_serviceM`, `occ_female_sales_officeE`, `occ_female_sales_officeM`, `occ_female_nat_resources_const_maintE`, `occ_female_nat_resources_const_maintM`, `occ_female_prod_transp_materialE`, `occ_female_prod_transp_materialM`, `ind_totalE`, `ind_totalM`, `ind_male_ag_miningE`, `ind_male_ag_miningM`, `ind_male_constructionE`, `ind_male_constructionM`, `ind_male_manufacturingE`, `ind_male_manufacturingM`, `ind_male_wholesaleE`, `ind_male_wholesaleM`, `ind_male_retailE`, `ind_male_retailM`, `ind_male_transport_utilE`, `ind_male_transport_utilM`, `ind_male_informationE`, `ind_male_informationM`, `ind_male_finance_realE`, `ind_male_finance_realM`, `ind_male_professionalE`, `ind_male_professionalM`, `ind_male_educ_healthE`, `ind_male_educ_healthM`, `ind_male_arts_accomm_foodE`, `ind_male_arts_accomm_foodM`, `ind_male_otherE`, `ind_male_otherM`, `ind_male_public_adminE`, `ind_male_public_adminM`, `ind_female_ag_miningE`, `ind_female_ag_miningM`, `ind_female_constructionE`, `ind_female_constructionM`, `ind_female_manufacturingE`, `ind_female_manufacturingM`, `ind_female_wholesaleE`, `ind_female_wholesaleM`, `ind_female_retailE`, `ind_female_retailM`, `ind_female_transport_utilE`, `ind_female_transport_utilM`, `ind_female_informationE`, `ind_female_informationM`, `ind_female_finance_realE`, `ind_female_finance_realM`, `ind_female_professionalE`, `ind_female_professionalM`, `ind_female_educ_healthE`, `ind_female_educ_healthM`, `ind_female_arts_accomm_foodE`, `ind_female_arts_accomm_foodM`, `ind_female_otherE`, `ind_female_otherM`, `ind_female_public_adminE`, `ind_female_public_adminM`

## Lineage
- scripts/etl/staging/get_acs_labor.R (writes at lines 110-267)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
