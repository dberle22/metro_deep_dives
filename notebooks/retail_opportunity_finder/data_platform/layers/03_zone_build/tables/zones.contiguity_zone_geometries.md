# `zones.contiguity_zone_geometries`

- Grain: one row per `market_key`, `zone_id`
- Published by: `zone_build_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/tables/zones.contiguity_zone_geometries.R`
- Status: implemented; table-owned geometry asset extracted on `2026-04-06`

## Table role

- This table stores dissolved contiguity-zone polygons in `geom_wkt` form.
- It is the map-facing geometry output for the touching-based zone system.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/03_zone_build/tables/zones.contiguity_zone_geometries.R`
- Live `run_timestamp` range: `2026-04-06 17:25:53.587299` to `2026-04-06 17:27:54.113616`
- Live rows: `749`
- Live distinct `market_key`: `115`
- Live distinct `cbsa_code`: `115`
- Live column count: `16`
- Live state scope coverage:
  - `FL`: `28` markets / `283` rows
  - `GA`: `36` markets / `199` rows
  - `NC`: `37` markets / `171` rows
  - `SC`: `14` markets / `96` rows

## Live multi-market snapshot

- Dissolved contiguity geometries published: `749`
- Geometry rows align one-to-one with the current contiguity summary rows.
- The table carries area and label-point fields (`zone_area_sq_mi`, `label_lon`, `label_lat`) for downstream map annotation.
- Duplicate `(market_key, zone_id)` keys: `0`

## Scope diagnosis

- The live geometry table is now a multi-market southeast publication for the `115` zone-ready markets.
- The geometry extractor asset remains the right management target.
- The remaining coverage gap is limited to the two skipped markets whose cluster-seed tracts are not fully represented in the tract geometry slice.

## Managed-path notes

- The geometry publication now has a dedicated table-owned asset and table-specific `build_source`.
