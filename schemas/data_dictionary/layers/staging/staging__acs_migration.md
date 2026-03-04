# Data Dictionary: staging ACS Migration Group

## Overview
- Schema: `staging`
- Group: `ACS Migration`
- Tables in group: 11
- Row count range across tables: 13 to 433,172

## Tables
- `acs_migration_county`
- `acs_migration_division`
- `acs_migration_place`
- `acs_migration_region`
- `acs_migration_state`
- `acs_migration_tract_fl`
- `acs_migration_tract_ga`
- `acs_migration_tract_nc`
- `acs_migration_tract_sc`
- `acs_migration_us`
- `acs_migration_zcta`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 23
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `GEOID`, `year`, `NAME`, `mig_totalE`, `mig_totalM`, `mig_same_houseE`, `mig_same_houseM`, `mig_moved_same_cntyE`, `mig_moved_same_cntyM`, `mig_moved_same_stE`, `mig_moved_same_stM`, `mig_moved_diff_stE`, `mig_moved_diff_stM`, `mig_moved_abroadE`, `mig_moved_abroadM`, `pop_nativity_totalE`, `pop_nativity_totalM`, `pop_nativeE`, `pop_nativeM`, `pop_foreign_bornE`, `pop_foreign_bornM`, `pop_foreign_born_citizenE`, `pop_foreign_born_citizenM`

## Lineage
- scripts/etl/staging/get_acs_migration.R (writes by geography; see dbWriteTable calls)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
