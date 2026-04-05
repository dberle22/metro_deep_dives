# Layer 01 - Foundation Features

This layer owns reusable tract- and metro-level analytical features consumed by scoring and downstream notebook builds.

## Structure
- `tables/<table_name>/README.md` describes the table contract, grain, and migration state.
- `tables/<table_name>/build.sql` or `build.R` is the table-owned build asset when that table has been migrated.
- `foundation_feature_workflow.R` is the layer orchestrator that builds and publishes the tables into DuckDB.
- `run_foundation_features_layer.R` is the executable entrypoint for the layer.

## Current State
- `foundation.cbsa_features` now has a table-owned SQL definition in `tables/cbsa_features/build.sql`.
- Other feature queries still live in shared paths or workflow logic during the transition, but now have explicit table folders in this layer.
- Section 02 and Section 03 consume these features directly.

## Transition Goal
- Treat feature products as upstream data platform assets, not notebook-owned intermediates.
- Keep SQL-based feature generation reusable across markets.

## Current Products
- `foundation.cbsa_features`
- `foundation.tract_features`
- `foundation.market_tract_geometry`
- `foundation.market_county_geometry`
- `foundation.market_cbsa_geometry`
- optional context tables when market context artifacts exist:
  - `foundation.context_cbsa_boundary`
  - `foundation.context_county_boundary`
  - `foundation.context_places`
  - `foundation.context_major_roads`
  - `foundation.context_water`
- QA outputs:
  - `qa.foundation_validation_results`
  - `qa.foundation_null_rates`

## Notes
- This layer now has an explicit per-table ownership map under `tables/` for both foundation and QA outputs produced by the layer.
- `cbsa_features` is the first fully migrated table-owned build asset in this layer.
- Downstream consumers should treat DuckDB tables as the interface; any direct SQL reads that still exist elsewhere are transitional and will be migrated in a separate pass.
- `tract_features` are rendered dynamically for the active market/year from the existing SQL file before publication.
- Section 02 now has a dedicated input module that prefers these foundation tables and falls back to legacy SQL if they are missing.
