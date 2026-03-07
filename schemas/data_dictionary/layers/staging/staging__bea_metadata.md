# Data Dictionary: staging BEA Metadata Group

## Overview
- Schema: `staging`
- Group: `BEA Metadata`
- Tables in group: 2
- Row count range across tables: 101 to 7,936

## Tables
- `bea_regional_line_codes`
- `bea_regional_tables`

## Contract Summary
- This group has multiple contract variants across tables.
- Variant count: 2
  - Variant 1: 3 columns (1 table(s))
    - Tables: `bea_regional_tables`
  - Variant 2: 5 columns (1 table(s))
    - Tables: `bea_regional_line_codes`

## Shared Columns
- `dataset`

## Lineage
- scripts/etl/staging/get_bea.R (metadata generation at lines 52-79; script currently writes metadata to silver at lines 81-85)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
