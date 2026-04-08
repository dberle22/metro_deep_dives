# Layer 01 - Foundation Features

This layer owns reusable tract- and metro-level analytical features plus geometry support tables consumed by scoring and downstream notebook builds. The target end state is national, but current tract coverage is still constrained by upstream geography assets.

## Structure
- `tables/` is a flat table registry for this layer.
- Table-owned assets are named directly for the DuckDB table, for example `foundation.cbsa_features.sql`, `foundation.cbsa_features.R`, or `foundation.cbsa_features.md`.
- `foundation_feature_workflow.R` is the layer orchestrator that builds and publishes managed DuckDB tables for this layer.
- `run_foundation_features_layer.R` is the executable entrypoint for the layer.

## Current State
- `foundation.cbsa_features`, `foundation.tract_features`, and the three `market_*_geometry` tables are now managed layer outputs with table-owned SQL in `tables/`.
- `foundation.context_*` assets are documented transitional readers with lightweight table-owned `.R` files, but they are not required DuckDB-published layer outputs.
- Section 02, scoring, and serving consumers now read the managed foundation tables and filter by `cbsa_code` where needed.

## Transition Goal
- Treat feature products as upstream data platform assets, not notebook-owned intermediates.
- Keep SQL-based feature generation reusable across markets.
- Keep notebook cartography helpers available as transitional R artifacts until they are either retired or promoted into a dedicated managed geometry/context layer.

## Current Products
- Managed DuckDB outputs:
- `foundation.cbsa_features`
- `foundation.tract_features`
- `foundation.market_tract_geometry`
- `foundation.market_county_geometry`
- `foundation.market_cbsa_geometry`
- Transitional documented R artifacts:
  - `foundation.context_cbsa_boundary`
  - `foundation.context_county_boundary`
  - `foundation.context_places`
  - `foundation.context_major_roads`
  - `foundation.context_water`
- QA outputs:
  - `qa.foundation_validation_results`
  - `qa.foundation_geography_coverage`
  - `qa.foundation_null_rates`

## Notes
- This layer now has an explicit per-table ownership map under `tables/` for both foundation and QA outputs produced by the layer.
- Core analytical and geometry foundation tables are table-owned managed assets in this layer.
- Downstream consumers should treat DuckDB managed tables as the interface; any direct SQL reads that still exist elsewhere are transitional and should be migrated separately.
- `tract_features` and `market_tract_geometry` are published from the upstream tract backbone currently available in `silver.xwalk_tract_county` and `geo.tracts_supported_states`, with downstream consumers expected to filter by `cbsa_code`.
- Current status after the upstream geography expansion:
  - `silver.xwalk_tract_county` and `ref.tract_dim` now cover the national tract universe
  - `metro_deep_dive.geo.tracts_all_us` now exists as the canonical all-tract geometry source, with `geo.tracts_supported_states` retained as a compatibility alias during migration
  - `foundation.market_tract_geometry` now publishes from a national tract geometry backbone
  - `foundation.tract_features` is still not fully national because its tract-level ACS KPI parents remain limited to the currently staged ACS tract states
- The remaining ROF follow-up is not another foundation-layer redesign. It is a future upstream expansion of ACS tract staging and silver/gold KPI tables so `foundation.tract_features` can inherit national coverage cleanly.
- Target geography backbone:
  - `ref.tract_dim` should become one row per U.S. tract from a national `silver.xwalk_tract_county`
  - `foundation.tract_features` should become one row per U.S. tract for the target year, with `cbsa_code` populated where applicable
  - `foundation.market_tract_geometry` should remain the CBSA-keyed serving table for metro-linked tracts
  - `metro_deep_dive.geo.tracts_all_us` should become the canonical all-tract geometry source, with `geo.tracts_supported_states` retained only as a compatibility alias during migration
- Future follow-up needed for full national `foundation.tract_features`:
  - national tract staging for ACS age, race, education, income, housing, and transport inputs
  - national rebuilds of the related silver KPI tables and `gold.population_demographics`
  - foundation-layer rebuild after those upstream KPI sources are expanded
- `foundation.context_*` assets remain documented compatibility artifacts sourced from Section 02 context ingestion and are no longer republished into DuckDB by this layer.
- Profiled note: `foundation.tract_features` contains `553` rows with null `cbsa_code`, but they currently appear to be expected non-CBSA tracts rather than a broken join. Those rows roll up to `97` counties absent from `metro_deep_dive.silver.xwalk_cbsa_county`, which is why they also do not appear in the CBSA-keyed tract geometry table.
