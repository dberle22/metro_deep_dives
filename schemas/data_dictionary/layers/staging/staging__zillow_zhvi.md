# Data Dictionary: staging Zillow ZHVI Group

## Overview
- Schema: `staging`
- Group: `Zillow ZHVI`
- Tables in group: 4
- Row count range across tables: 9,078 to 4,683,002

## Tables
- `zillow_zhvi_city`
- `zillow_zhvi_county`
- `zillow_zhvi_state`
- `zillow_zhvi_zip_code`

## Contract Summary
- This group has multiple contract variants across tables.
- Variant count: 4
  - Variant 1: 6 columns (1 table(s))
    - Tables: `zillow_zhvi_state`
  - Variant 2: 9 columns (1 table(s))
    - Tables: `zillow_zhvi_city`
  - Variant 3: 10 columns (1 table(s))
    - Tables: `zillow_zhvi_zip_code`
  - Variant 4: 11 columns (1 table(s))
    - Tables: `zillow_zhvi_county`

## Shared Columns
- `state`, `region_type`, `date`, `year`, `month`, `zhvi`

## Lineage
- scripts/etl/staging/get_zillow.R (ZHVI writes at lines 183, 207, 230, 253)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
