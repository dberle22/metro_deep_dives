# Data Dictionary: staging ACS Social Infrastructure Group

## Overview
- Schema: `staging`
- Group: `ACS Social Infrastructure`
- Tables in group: 11
- Row count range across tables: 10 to 333,812

## Tables
- `acs_social_infra_county`
- `acs_social_infra_division`
- `acs_social_infra_place`
- `acs_social_infra_region`
- `acs_social_infra_state`
- `acs_social_infra_tract_fl`
- `acs_social_infra_tract_ga`
- `acs_social_infra_tract_nc`
- `acs_social_infra_tract_sc`
- `acs_social_infra_us`
- `acs_social_infra_zcta`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 43
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `GEOID`, `year`, `NAME`, `hh_totalE`, `hh_totalM`, `hh_familyE`, `hh_familyM`, `hh_marriedE`, `hh_marriedM`, `hh_other_familyE`, `hh_other_familyM`, `hh_nonfamilyE`, `hh_nonfamilyM`, `hh_nonfam_aloneE`, `hh_nonfam_aloneM`, `hh_nonfam_not_aloneE`, `hh_nonfam_not_aloneM`, `ins_totalE`, `ins_totalM`, `ins_u19_one_planE`, `ins_u19_one_planM`, `ins_u19_two_plansE`, `ins_u19_two_plansM`, `ins_u19_uncoveredE`, `ins_u19_uncoveredM`, `ins_19_34_one_planE`, `ins_19_34_one_planM`, `ins_19_34_two_plansE`, `ins_19_34_two_plansM`, `ins_19_34_uncoveredE`, `ins_19_34_uncoveredM`, `ins_35_64_one_planE`, `ins_35_64_one_planM`, `ins_35_64_two_plansE`, `ins_35_64_two_plansM`, `ins_35_64_uncoveredE`, `ins_35_64_uncoveredM`, `ins_65u_one_planE`, `ins_65u_one_planM`, `ins_65u_two_plansE`, `ins_65u_two_plansM`, `ins_65u_uncoveredE`, `ins_65u_uncoveredM`

## Lineage
- scripts/etl/staging/get_acs_social_infra.R (writes by geography; see dbWriteTable calls)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
