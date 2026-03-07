# Data Dictionary: staging ACS Housing Group

## Overview
- Schema: `staging`
- Group: `ACS Housing`
- Tables in group: 11
- Row count range across tables: 13 to 433,172

## Tables
- `acs_housing_county`
- `acs_housing_division`
- `acs_housing_place`
- `acs_housing_region`
- `acs_housing_state`
- `acs_housing_tract_fl`
- `acs_housing_tract_ga`
- `acs_housing_tract_nc`
- `acs_housing_tract_sc`
- `acs_housing_us`
- `acs_housing_zcta`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 71
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `GEOID`, `year`, `NAME`, `hu_totalE`, `hu_totalM`, `occ_totalE`, `occ_totalM`, `occ_occupiedE`, `occ_occupiedM`, `occ_vacantE`, `occ_vacantM`, `tenure_totalE`, `tenure_totalM`, `owner_occupiedE`, `owner_occupiedM`, `renter_occupiedE`, `renter_occupiedM`, `median_gross_rentE`, `median_gross_rentM`, `median_home_valueE`, `median_home_valueM`, `rent_burden_totalE`, `rent_burden_totalM`, `rent_lt_10E`, `rent_lt_10M`, `rent_10_14E`, `rent_10_14M`, `rent_15_19E`, `rent_15_19M`, `rent_20_24E`, `rent_20_24M`, `rent_25_29E`, `rent_25_29M`, `rent_30_34E`, `rent_30_34M`, `rent_35_39E`, `rent_35_39M`, `rent_40_49E`, `rent_40_49M`, `rent_50_plusE`, `rent_50_plusM`, `rent_not_computedE`, `rent_not_computedM`, `median_owner_costs_totalE`, `median_owner_costs_totalM`, `median_owner_costs_mortgageE`, `median_owner_costs_mortgageM`, `median_owner_costs_no_mortgageE`, `median_owner_costs_no_mortgageM`, `struct_totalE`, `struct_totalM`, `struct_1_detE`, `struct_1_detM`, `struct_1_attE`, `struct_1_attM`, `struct_2_unitsE`, `struct_2_unitsM`, `struct_3_4_unitsE`, `struct_3_4_unitsM`, `struct_5_9_unitsE`, `struct_5_9_unitsM`, `struct_10_19E`, `struct_10_19M`, `struct_20_49E`, `struct_20_49M`, `struct_50_plusE`, `struct_50_plusM`, `struct_mobileE`, `struct_mobileM`, `struct_otherE`, `struct_otherM`

## Lineage
- scripts/etl/staging/get_acs_housing.R (writes by geography; see dbWriteTable calls)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
