# Data Dictionary: staging ACS Age Group

## Overview
- Schema: `staging`
- Group: `ACS Age`
- Tables in group: 11
- Row count range across tables: 13 to 433,172

## Tables
- `acs_age_county`
- `acs_age_division`
- `acs_age_place`
- `acs_age_region`
- `acs_age_state`
- `acs_age_tract_fl`
- `acs_age_tract_ga`
- `acs_age_tract_nc`
- `acs_age_tract_sc`
- `acs_age_us`
- `acs_age_zcta`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 103
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `GEOID`, `year`, `NAME`, `pop_totalE`, `pop_totalM`, `median_age.E`, `median_age.M`, `pop_male_totalE`, `pop_male_totalM`, `pop_age_male_under5E`, `pop_age_male_under5M`, `pop_age_male_5_9E`, `pop_age_male_5_9M`, `pop_age_male_10_14E`, `pop_age_male_10_14M`, `pop_age_male_15_17E`, `pop_age_male_15_17M`, `pop_age_male_18_19E`, `pop_age_male_18_19M`, `pop_age_male_20E`, `pop_age_male_20M`, `pop_age_male_21E`, `pop_age_male_21M`, `pop_age_male_22_24E`, `pop_age_male_22_24M`, `pop_age_male_25_29E`, `pop_age_male_25_29M`, `pop_age_male_30_34E`, `pop_age_male_30_34M`, `pop_age_male_35_39E`, `pop_age_male_35_39M`, `pop_age_male_40_44E`, `pop_age_male_40_44M`, `pop_age_male_45_49E`, `pop_age_male_45_49M`, `pop_age_male_50_54E`, `pop_age_male_50_54M`, `pop_age_male_55_59E`, `pop_age_male_55_59M`, `pop_age_male_60_61E`, `pop_age_male_60_61M`, `pop_age_male_62_64E`, `pop_age_male_62_64M`, `pop_age_male_65_66E`, `pop_age_male_65_66M`, `pop_age_male_67_69E`, `pop_age_male_67_69M`, `pop_age_male_70_74E`, `pop_age_male_70_74M`, `pop_age_male_75_79E`, `pop_age_male_75_79M`, `pop_age_male_80_84E`, `pop_age_male_80_84M`, `pop_age_male_85_plusE`, `pop_age_male_85_plusM`, `pop_female_totalE`, `pop_female_totalM`, `pop_age_female_under5E`, `pop_age_female_under5M`, `pop_age_female_5_9E`, `pop_age_female_5_9M`, `pop_age_female_10_14E`, `pop_age_female_10_14M`, `pop_age_female_15_17E`, `pop_age_female_15_17M`, `pop_age_female_18_19E`, `pop_age_female_18_19M`, `pop_age_female_20E`, `pop_age_female_20M`, `pop_age_female_21E`, `pop_age_female_21M`, `pop_age_female_22_24E`, `pop_age_female_22_24M`, `pop_age_female_25_29E`, `pop_age_female_25_29M`, `pop_age_female_30_34E`, `pop_age_female_30_34M`, `pop_age_female_35_39E`, `pop_age_female_35_39M`, `pop_age_female_40_44E`, `pop_age_female_40_44M`, `pop_age_female_45_49E`, `pop_age_female_45_49M`, `pop_age_female_50_54E`, `pop_age_female_50_54M`, `pop_age_female_55_59E`, `pop_age_female_55_59M`, `pop_age_female_60_61E`, `pop_age_female_60_61M`, `pop_age_female_62_64E`, `pop_age_female_62_64M`, `pop_age_female_65_66E`, `pop_age_female_65_66M`, `pop_age_female_67_69E`, `pop_age_female_67_69M`, `pop_age_female_70_74E`, `pop_age_female_70_74M`, `pop_age_female_75_79E`, `pop_age_female_75_79M`, `pop_age_female_80_84E`, `pop_age_female_80_84M`, `pop_age_female_85_plusE`, `pop_age_female_85_plusM`

## Lineage
- scripts/etl/staging/get_acs_age.R (writes at lines 92-249)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
