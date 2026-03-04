# Data Dictionary: staging HUD CHAS Group

## Overview
- Schema: `staging`
- Group: `HUD CHAS`
- Tables in group: 3
- Row count range across tables: 7,956 to 4,881,924

## Tables
- `hud_chas_county`
- `hud_chas_place`
- `hud_chas_state`

## Contract Summary
- This group has multiple contract variants across tables.
- Variant count: 3
  - Variant 1: 16 columns (1 table(s))
    - Tables: `hud_chas_state`
  - Variant 2: 17 columns (1 table(s))
    - Tables: `hud_chas_place`
  - Variant 3: 17 columns (1 table(s))
    - Tables: `hud_chas_county`

## Shared Columns
- `source`, `sumlevel`, `geoid`, `name`, `st`, `variable`, `estimate`, `line_type`, `tenure`, `household_income`, `household_type`, `cost_burden`, `chas_period`, `year`, `geo_level`

## Lineage
- scripts/etl/staging/get_hud_chas.R (writes at lines 104, 132, 154)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
