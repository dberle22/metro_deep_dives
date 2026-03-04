# Data Dictionary: staging BEA CAINC1 Group

## Overview
- Schema: `staging`
- Group: `BEA CAINC1`
- Tables in group: 3
- Row count range across tables: 4,320 to 226,080

## Tables
- `bea_regional_cbsa_cainc1`
- `bea_regional_county_cainc1`
- `bea_regional_state_cainc1`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 12
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `code`, `table`, `geo_level`, `geo_id`, `geo_name`, `period`, `line_code`, `unit_raw`, `unit_mult`, `value_raw`, `value`, `note_ref`

## Lineage
- scripts/etl/staging/get_bea.R (CAINC1 staging writes at lines 256, 276, 294)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
