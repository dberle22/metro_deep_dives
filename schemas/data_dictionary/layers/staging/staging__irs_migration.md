# Data Dictionary: staging IRS Migration Group

## Overview
- Schema: `staging`
- Group: `IRS Migration`
- Tables in group: 3
- Row count range across tables: 28,050 to 627,182

## Tables
- `irs_inflow_migration_county`
- `irs_inflow_migration_state`
- `irs_migration_state`

## Contract Summary
- This group has multiple contract variants across tables.
- Variant count: 2
  - Variant 1: 11 columns (2 table(s))
    - Tables: `irs_inflow_migration_state`, `irs_migration_state`
  - Variant 2: 15 columns (1 table(s))
    - Tables: `irs_inflow_migration_county`

## Shared Columns
- `flow_id`, `year`, `origin_year`, `dest_year`, `dest_state_fips`, `origin_state_fips`, `n_returns`, `n_exemptions`, `agi_thousands`, `agi`

## Lineage
- scripts/etl/staging/get_irs_migration.R (writes at lines 364-365, 496-497)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
