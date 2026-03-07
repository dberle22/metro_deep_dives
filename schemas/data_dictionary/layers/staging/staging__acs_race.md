# Data Dictionary: staging ACS Race Group

## Overview
- Schema: `staging`
- Group: `ACS Race`
- Tables in group: 11
- Row count range across tables: 13 to 433,172

## Tables
- `acs_race_county`
- `acs_race_division`
- `acs_race_place`
- `acs_race_region`
- `acs_race_state`
- `acs_race_tract_fl`
- `acs_race_tract_ga`
- `acs_race_tract_nc`
- `acs_race_tract_sc`
- `acs_race_us`
- `acs_race_zcta`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 21
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `GEOID`, `year`, `NAME`, `pop_total_b03002E`, `pop_total_b03002M`, `white_nonhispE`, `white_nonhispM`, `black_nonhispE`, `black_nonhispM`, `amind_nonhispE`, `amind_nonhispM`, `asian_nonhispE`, `asian_nonhispM`, `pacisl_nonhispE`, `pacisl_nonhispM`, `other_nonhispE`, `other_nonhispM`, `two_plus_nonhispE`, `two_plus_nonhispM`, `hispanic_anyE`, `hispanic_anyM`

## Lineage
- scripts/etl/staging/get_acs_race.R (writes by geography; see dbWriteTable calls)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
