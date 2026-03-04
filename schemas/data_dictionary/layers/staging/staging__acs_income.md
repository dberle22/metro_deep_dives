# Data Dictionary: staging ACS Income Group

## Overview
- Schema: `staging`
- Group: `ACS Income`
- Tables in group: 11
- Row count range across tables: 13 to 433,172

## Tables
- `acs_income_county`
- `acs_income_division`
- `acs_income_place`
- `acs_income_region`
- `acs_income_state`
- `acs_income_tract_fl`
- `acs_income_tract_ga`
- `acs_income_tract_nc`
- `acs_income_tract_sc`
- `acs_income_us`
- `acs_income_zcta`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 47
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `GEOID`, `year`, `NAME`, `median_hh_incomeE`, `median_hh_incomeM`, `per_capita_incomeE`, `per_capita_incomeM`, `pov_universeE`, `pov_universeM`, `pov_belowE`, `pov_belowM`, `hh_inc_totalE`, `hh_inc_totalM`, `hh_inc_lt10kE`, `hh_inc_lt10kM`, `hh_inc_10k_15kE`, `hh_inc_10k_15kM`, `hh_inc_15k_20kE`, `hh_inc_15k_20kM`, `hh_inc_20k_25kE`, `hh_inc_20k_25kM`, `hh_inc_25k_30kE`, `hh_inc_25k_30kM`, `hh_inc_30k_35kE`, `hh_inc_30k_35kM`, `hh_inc_35k_40kE`, `hh_inc_35k_40kM`, `hh_inc_40k_45kE`, `hh_inc_40k_45kM`, `hh_inc_45k_50kE`, `hh_inc_45k_50kM`, `hh_inc_50k_60kE`, `hh_inc_50k_60kM`, `hh_inc_60k_75kE`, `hh_inc_60k_75kM`, `hh_inc_75k_100kE`, `hh_inc_75k_100kM`, `hh_inc_100k_125kE`, `hh_inc_100k_125kM`, `hh_inc_125k_150kE`, `hh_inc_125k_150kM`, `hh_inc_150k_200kE`, `hh_inc_150k_200kM`, `hh_inc_200k_plusE`, `hh_inc_200k_plusM`, `gini_indexE`, `gini_indexM`

## Lineage
- scripts/etl/staging/get_acs_income.R (writes by geography; see dbWriteTable calls)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
