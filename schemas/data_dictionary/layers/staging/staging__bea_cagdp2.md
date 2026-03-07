# Data Dictionary: staging BEA CAGDP2 Group

## Overview
- Schema: `staging`
- Group: `BEA CAGDP2`
- Tables in group: 3
- Row count range across tables: 38,640 to 1,222,256

## Tables
- `bea_regional_cbsa_cagdp2`
- `bea_regional_county_cagdp2`
- `bea_regional_state_cagdp2`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 12
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `code`, `table`, `geo_level`, `geo_id`, `geo_name`, `period`, `line_code`, `unit_raw`, `unit_mult`, `value_raw`, `value`, `note_ref`

## Lineage
- scripts/etl/staging/get_bea.R (CAGDP2 staging writes at lines 553, 661, 769)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
