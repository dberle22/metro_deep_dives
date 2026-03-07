# Data Dictionary: staging HUD FMR Group

## Overview
- Schema: `staging`
- Group: `HUD FMR`
- Tables in group: 3
- Row count range across tables: 4,764 to 27,331

## Tables
- `hud_fmr_county`
- `hud_fmr_zip`
- `hud_rent50_county`

## Contract Summary
- This group has multiple contract variants across tables.
- Variant count: 3
  - Variant 1: 11 columns (1 table(s))
    - Tables: `hud_fmr_zip`
  - Variant 2: 14 columns (1 table(s))
    - Tables: `hud_fmr_county`
  - Variant 3: 15 columns (1 table(s))
    - Tables: `hud_rent50_county`

## Shared Columns
- `hud_area_code`, `hud_area_name`, `period`

## Lineage
- scripts/etl/staging/get_hud_fmr.R (writes at lines 129, 161, 196)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
