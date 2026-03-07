# Data Dictionary: staging BPS Group

## Overview
- Schema: `staging`
- Group: `BPS`
- Tables in group: 5
- Row count range across tables: 180 to 857,644

## Tables
- `bps_county`
- `bps_division`
- `bps_place`
- `bps_region`
- `bps_state`

## Contract Summary
- This group has multiple contract variants across tables.
- Variant count: 5
  - Variant 1: 22 columns (1 table(s))
    - Tables: `bps_division`
  - Variant 2: 22 columns (1 table(s))
    - Tables: `bps_region`
  - Variant 3: 22 columns (1 table(s))
    - Tables: `bps_state`
  - Variant 4: 26 columns (1 table(s))
    - Tables: `bps_county`
  - Variant 5: 30 columns (1 table(s))
    - Tables: `bps_place`

## Shared Columns
- `FILE_NAME`, `LOCATION_TYPE`, `PERIOD`, `SURVEY_DATE`, `YEAR`, `TOTAL_BLDGS`, `TOTAL_UNITS`, `TOTAL_VALUE`, `BLDGS_1_UNIT`, `BLDGS_2_UNITS`, `BLDGS_3_4_UNITS`, `BLDGS_5_UNITS`, `UNITS_1_UNIT`, `UNITS_2_UNITS`, `UNITS_3_4_UNITS`, `UNITS_5_UNITS`, `VALUE_1_UNIT`, `VALUE_2_UNITS`, `VALUE_3_4_UNITS`, `VALUE_5_UNITS`

## Lineage
- scripts/etl/staging/get_bps.R (writes at lines 49, 63, 77, 110, 132)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
