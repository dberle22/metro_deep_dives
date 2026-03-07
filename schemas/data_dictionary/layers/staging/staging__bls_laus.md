# Data Dictionary: staging BLS LAUS Group

## Overview
- Schema: `staging`
- Group: `BLS LAUS`
- Tables in group: 1
- Row count range across tables: 48,305 to 48,305

## Tables
- `bls_laus_county`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 12
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `geo_level`, `geo_id`, `state_fips_code`, `county_fips_code`, `county_name`, `period`, `labor_force`, `employed`, `unemployed`, `unemployment_rate_percent`, `src`, `version`

## Lineage
- scripts/etl/staging/get_bls_laus.R (write at lines 134-135)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
