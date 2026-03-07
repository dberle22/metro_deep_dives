# Data Dictionary: staging Zillow ZORI Group

## Overview
- Schema: `staging`
- Group: `Zillow ZORI`
- Tables in group: 3
- Row count range across tables: 167,310 to 1,016,860

## Tables
- `zillow_zori_city`
- `zillow_zori_county`
- `zillow_zori_zip_code`

## Contract Summary
- This group has multiple contract variants across tables.
- Variant count: 3
  - Variant 1: 9 columns (1 table(s))
    - Tables: `zillow_zori_city`
  - Variant 2: 10 columns (1 table(s))
    - Tables: `zillow_zori_zip_code`
  - Variant 3: 11 columns (1 table(s))
    - Tables: `zillow_zori_county`

## Shared Columns
- `region_type`, `state`, `metro`, `county_name`, `date`, `year`, `month`, `zori`

## Lineage
- scripts/etl/staging/get_zillow.R (ZORI writes at lines 278, 301, 324)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
