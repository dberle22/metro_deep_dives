# `foundation.cbsa_features`

- Grain: one row per `cbsa_code`, `year`
- Published by: `foundation_feature_workflow.R`
- Build asset: `foundation.cbsa_features.sql`
- Status: migrated to a table-owned layer asset

This is the canonical home for the SQL that builds `foundation.cbsa_features` before publication to DuckDB.

## Current Materialized Table Snapshot

The current DuckDB table was profiled on `2026-04-06`.

- Table exists in DuckDB: `TRUE`
- Row count: `11,955`
- Distinct CBSAs: `925`
- Distinct years: `13`
- Year coverage: `2012` to `2024`
- Distinct `market_key` values: `1`
- Current materialized `market_key`: `jacksonville_fl`
- Current materialized `state_scope`: `FL`
- Current materialized `build_source`: `sql/features/cbsa_features.sql`

Important note:
- The table has not yet been rebuilt from the new layer-owned SQL path. The live DuckDB copy still records the legacy build source.

## Current Shape

The materialized table currently has `57` columns:

`market_key`, `state_scope`, `build_source`, `run_timestamp`, `cbsa_code`, `cbsa_name`, `cbsa_type`, `primary_state_abbr`, `land_area_sq_mi`, `state_fips`, `census_region`, `census_division`, `year`, `pop_total`, `national_pop_rank`, `national_pop_pctl`, `region_pop_rank`, `region_pop_pctl`, `pop_growth_3yr`, `national_pop_growth_3yr_rank`, `national_pop_growth_3yr_pctl`, `region_pop_growth_3yr_rank`, `region_pop_growth_3yr_pctl`, `pop_growth_5yr`, `national_pop_growth_5yr_rank`, `national_pop_growth_5yr_pctl`, `region_pop_growth_5yr_rank`, `region_pop_growth_5yr_pctl`, `median_gross_rent`, `national_gross_rent_rank`, `national_gross_rent_pctl`, `region_gross_rent_rank`, `region_gross_rent_pctl`, `median_home_value`, `national_home_value_rank`, `national_home_value_pctl`, `region_home_value_rank`, `region_home_value_pctl`, `pct_commute_wfh`, `national_wfh_rank`, `national_wfh_pctl`, `region_wfh_rank`, `region_wfh_pctl`, `mean_travel_time`, `national_travel_time_rank`, `national_travel_time_pctl`, `region_travel_time_rank`, `region_travel_time_pctl`, `commute_intensity_b`, `bps_total_units`, `bps_units_per_1k`, `bps_units_3yr_avg`, `bps_units_per_1k_3yr_avg`, `national_units_1k_avg_rank`, `national_units_1k_avg_pctl`, `region_units_1k_avg_rank`, `region_units_1k_avg_pctl`

Type summary:
- Metadata and identifiers are mostly `VARCHAR`
- `year` is `INTEGER`
- Metrics and rank/percentile fields are currently stored as `DOUBLE`

## Current Coverage

This is not a Jacksonville-only metro table in content. It is a national CBSA benchmark table published with Jacksonville market metadata attached.

- Region coverage:
  - `South`: `368` CBSAs / `4,784` rows
  - `Midwest`: `284` CBSAs / `3,692` rows
  - `West`: `176` CBSAs / `2,288` rows
  - `Northeast`: `97` CBSAs / `1,191` rows
- Division coverage spans all `9` census divisions
- CBSA type coverage:
  - `Micro Area`: `538` CBSAs / `6,974` rows
  - `Metro Area`: `387` CBSAs / `4,981` rows
- Largest primary-state counts by distinct CBSA include:
  - `TX`: `67`
  - `OH`: `41`
  - `NC`: `38`
  - `IN`: `37`
  - `GA`: `37`
  - `PA`: `36`
  - `CA`: `34`
  - `MI`: `33`
  - `IL`: `28`
  - `FL`: `28`

## Year Coverage Detail

- `2012` to `2021`: `918` CBSA rows per year
- `2022` to `2024`: `925` CBSA rows per year

This means `7` CBSAs appear only in the final three years of the current materialization.

## Example Live Rows

Sample materialized rows observed in DuckDB:

- `22420` / `Flint, MI` / `2013`
- `40420` / `Rockford, IL` / `2013`
- `49660` / `Youngstown-Warren, OH` / `2013`

## Management Notes

- The SQL definition now lives in `foundation.cbsa_features.sql`.
- The live DuckDB table should be rebuilt through the foundation layer orchestrator before we treat the new path as fully operational.
- Because this table is national in content but market-scoped in metadata, we should keep watching whether `market_key` belongs here long-term or whether this table should eventually split into:
  - a national benchmark table
  - a thinner market-serving view
