# `zones.cluster_zone_geometries`

- Grain: one row per `market_key`, `cluster_id`
- Published by: `zone_build_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/tables/zones.cluster_zone_geometries.R`
- Status: implemented; table-owned geometry asset extracted on `2026-04-06`

## Table role

- This table stores dissolved cluster-zone polygons in `geom_wkt` form.
- It is the map-serving geometry output for the default cluster-based zone system.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/03_zone_build/tables/zones.cluster_zone_geometries.R`
- Live `run_timestamp` range: `2026-04-06 17:25:53.64176` to `2026-04-06 17:27:54.244483`
- Live rows: `447`
- Live distinct `market_key`: `115`
- Live distinct `cbsa_code`: `115`
- Live column count: `14`
- Live state scope coverage:
  - `FL`: `28` markets / `130` rows
  - `GA`: `36` markets / `135` rows
  - `NC`: `37` markets / `124` rows
  - `SC`: `14` markets / `58` rows

## Live multi-market snapshot

- Dissolved cluster geometries published: `447`
- Geometry rows align one-to-one with the current cluster summary rows.
- The table carries `zone_area_sq_mi`, `label_lon`, and `label_lat` for map annotation support.
- Duplicate `(market_key, cluster_id)` keys: `0`

## Scope diagnosis

- The live geometry publication is now multi-market for the `115` zone-ready southeast markets.
- It still excludes `2` scored markets with tract-geometry gaps in the cluster-seed subset.
- The geometry asset itself is fine as the management target; the limitation is that the workflow only creates one market's cluster zones per run and writes them as the full table.
- The orchestration gap has been removed; the remaining limitation is geometry readiness in those skipped markets.

## Managed-path notes

- The geometry publication now has a dedicated table-owned asset and no longer stamps the generic layer root as its `build_source`.
