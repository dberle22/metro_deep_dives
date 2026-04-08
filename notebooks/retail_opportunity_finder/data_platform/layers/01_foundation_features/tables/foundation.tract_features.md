# `foundation.tract_features`

- Grain: one row per `cbsa_code`, `tract_geoid`, `year`
- Published by: `foundation_feature_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features/tables/foundation.tract_features.sql`
- Status: implemented; refactored toward a national precompute on `2026-04-06`

## Table role

- This table is intended to become a national tract feature spine for the target year.
- Market-specific consumers should filter by `cbsa_code` from the published table instead of rebuilding tract features for each market.
- Percentile and gate logic in the managed SQL is partitioned by `cbsa_code`, so market-relative tract scoring behavior is preserved.
- Current scope is limited by the upstream tract backbone, not by the table logic itself.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/01_foundation_features/tables/foundation.tract_features.sql`
- Live `run_timestamp`: `2026-04-06 10:17:53.114298`
- Live materialization scope: tract feature publication for `2024` over the current upstream tract backbone
- Live rows: `10573`
- Live distinct `cbsa_code`: `106`
- Live distinct `tract_geoid`: `10573`
- Live distinct `year`: `1` (`2024`)
- Live column count: `31`
- Live required columns: `Yes`

## Live Jacksonville coverage snapshot

- Jacksonville live rows: `340`
- County coverage in the live table: `12003` (4 tracts), `12019` (45), `12031` (218), `12089` (23), `12109` (50)
- Eligibility funnel counts: `gate_pop = 170`, `gate_price = 247`, `gate_density = 237`, `eligible_v1 = 79`
- Value ranges:
  - `pop_growth_3yr`: `-0.3702` to `1.2636`
  - `price_proxy_pctl`: `0.0000` to `0.9938`
  - `pop_density`: `4.2475` to `10870.26`

## Null checks

- `pop_total`: `0` nulls
- `median_gross_rent`: `14` nulls
- `median_home_value`: `3` nulls
- `mean_travel_time`: `1` null
- `median_hh_income`: `1` null

## Managed-path notes

- The table-owned SQL has been migrated into this layer and refactored to build a national tract feature spine partitioned by `cbsa_code`.
- Section 02 and tract scoring have been updated to filter the published foundation table by `cbsa_code`.
- The live DuckDB snapshot is now updated to the managed table-owned asset path.
- The ROF-side design is now considered aligned: tract backbone and tract geometry are upstream geography concerns, while the remaining feature-coverage gap is an upstream ACS tract KPI concern.
- The `553` live rows with `NULL cbsa_code` have now been profiled: they roll up to `97` counties, and all `97` of those counties are absent from `metro_deep_dive.silver.xwalk_cbsa_county`.
- State split of the null-`cbsa_code` tract rows: `GA = 239` across `53` counties, `NC = 221` across `29` counties, `FL = 93` across `15` counties.
- Largest affected counties by tract count are `37061 Duplin NC (21)`, `37163 Sampson NC (20)`, `37047 Columbus NC (15)`, `37077 Granville NC (15)`, and `12063 Jackson FL (13)`.
- Current interpretation: this looks like expected non-CBSA tract coverage rather than a broken tract join, so the QA warning should be treated as a geography-scope note unless the CBSA county crosswalk itself is expanded.
- Geography-side target design is now in place:
  - `silver.xwalk_tract_county` now feeds a national `ref.tract_dim`
  - `metro_deep_dive.geo.tracts_all_us` now exists as the canonical all-tract geometry source
  - this table can stay table-owned and inherit national geography inputs without market-specific rewrites
- Updated status after the geography rebuild:
  - the tract universe and tract geometry backbone are now national
  - this table still remains coverage-limited because `gold.population_demographics`, `silver.income_kpi`, `silver.housing_kpi`, and `silver.transport_kpi` only contain tract rows for `FL`, `GA`, `NC`, and `SC`
  - future work should expand those ACS tract KPI parents upstream rather than further reworking the foundation asset itself
