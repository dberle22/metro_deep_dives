# `foundation.market_cbsa_geometry`

- Grain: one row per `cbsa_code`
- Published by: `foundation_feature_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features/tables/foundation.market_cbsa_geometry.sql`
- Status: implemented; generalized to national publication on `2026-04-06`

## Table role

- National CBSA boundary geometry service published in DuckDB-friendly `geom_wkt` form.
- Downstream consumers should filter by `cbsa_code` when they need a specific metro boundary.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/01_foundation_features/tables/foundation.market_cbsa_geometry.sql`
- Live `run_timestamp`: `2026-04-06 10:45:15.920377`
- Live rows: `935`
- Live distinct `cbsa_code`: `935`
- Live duplicate `cbsa_code` rows: `0`
- Live column count: `5`

## Jacksonville slice

- Jacksonville (`27260`) row count: `1`
- Example label: `Jacksonville, FL`

## Important findings

- The prior market boundary handoff has been replaced with a generalized national CBSA geometry table.
- This is the cleanest of the three geometry tables because the natural grain is already one row per `cbsa_code`.
