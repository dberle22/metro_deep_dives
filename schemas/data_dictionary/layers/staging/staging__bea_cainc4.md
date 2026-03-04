# Data Dictionary: staging BEA CAINC4 Group

## Overview
- Schema: `staging`
- Group: `BEA CAINC4`
- Tables in group: 3
- Row count range across tables: 24,480 to 1,281,120

## Tables
- `bea_regional_cbsa_cainc4`
- `bea_regional_county_cainc4`
- `bea_regional_state_cainc4`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 12
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `code`, `table`, `geo_level`, `geo_id`, `geo_name`, `period`, `line_code`, `unit_raw`, `unit_mult`, `value_raw`, `value`, `note_ref`

## Lineage
- scripts/etl/staging/get_bea.R (CAINC4 staging writes at lines 332, 406, 423)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
