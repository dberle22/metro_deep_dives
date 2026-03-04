# Data Dictionary: staging ACS Education Group

## Overview
- Schema: `staging`
- Group: `ACS Education`
- Tables in group: 11
- Row count range across tables: 13 to 433,172

## Tables
- `acs_edu_county`
- `acs_edu_division`
- `acs_edu_place`
- `acs_edu_region`
- `acs_edu_state`
- `acs_edu_tract_fl`
- `acs_edu_tract_ga`
- `acs_edu_tract_nc`
- `acs_edu_tract_sc`
- `acs_edu_us`
- `acs_edu_zcta`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 53
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `GEOID`, `year`, `NAME`, `edu_total_25pE`, `edu_total_25pM`, `edu_no_schoolingE`, `edu_no_schoolingM`, `edu_nurseryE`, `edu_nurseryM`, `edu_kindergartenE`, `edu_kindergartenM`, `edu_grade1E`, `edu_grade1M`, `edu_grade2E`, `edu_grade2M`, `edu_grade3E`, `edu_grade3M`, `edu_grade4E`, `edu_grade4M`, `edu_grade5E`, `edu_grade5M`, `edu_grade6E`, `edu_grade6M`, `edu_grade7E`, `edu_grade7M`, `edu_grade8E`, `edu_grade8M`, `edu_grade9E`, `edu_grade9M`, `edu_grade10E`, `edu_grade10M`, `edu_grade11E`, `edu_grade11M`, `edu_grade12_no_diplomaE`, `edu_grade12_no_diplomaM`, `edu_hs_diplomaE`, `edu_hs_diplomaM`, `edu_ged_alt_credentialE`, `edu_ged_alt_credentialM`, `edu_some_college_lt1yrE`, `edu_some_college_lt1yrM`, `edu_some_college_ge1yrE`, `edu_some_college_ge1yrM`, `edu_associatesE`, `edu_associatesM`, `edu_bachelorsE`, `edu_bachelorsM`, `edu_mastersE`, `edu_mastersM`, `edu_professionalE`, `edu_professionalM`, `edu_doctorateE`, `edu_doctorateM`

## Lineage
- scripts/etl/staging/get_acs_edu.R (writes by geography; see dbWriteTable calls)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
