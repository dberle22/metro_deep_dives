# `zones.cluster_assignments`

- Grain: one row per `market_key`, `tract_geoid`
- Published by: `zone_build_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/tables/zones.cluster_assignments.R`
- Status: implemented; table-owned cluster builder extracted on `2026-04-06`

## Table role

- This is the tract-to-cluster assignment table for the default proximity-based zone system.
- It carries the cluster identity fields alongside tract metrics so downstream consumers do not need to rejoin tract scoring inputs.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/03_zone_build/tables/zones.cluster_assignments.R`
- Live `run_timestamp` range: `2026-04-06 17:25:53.634131` to `2026-04-06 17:27:54.234874`
- Live rows: `2629`
- Live distinct `market_key`: `115`
- Live distinct `cbsa_code`: `115`
- Live column count: `18`
- Live state scope coverage:
  - `FL`: `28` markets / `1267` rows
  - `GA`: `36` markets / `615` rows
  - `NC`: `37` markets / `475` rows
  - `SC`: `14` markets / `272` rows

## Live multi-market snapshot

- Candidate tracts assigned to clusters: `2629`
- Duplicate `(market_key, tract_geoid)` keys: `0`
- Downstream cluster summary/geometries resolve to `447` cluster zones in the current live slice.

## Scope diagnosis

- This live assignment table is now a southeast multi-market publication for the `115` zone-ready markets.
- It excludes the `2` skipped markets where cluster-seed tracts are missing from tract geometry, which is especially important for cluster-zone construction.
- The clustering asset is still the right table-owned `.R` target because it contains procedural spatial logic.
- The updated layer workflow now loops the clustering logic across the ready market set and publishes the combined output without touching live Layer 02 scoring tables.

## Managed-path notes

- The projected-centroid clustering logic now lives in a table-owned asset.
- Cluster summary and geometry outputs reuse the same in-memory cluster bundle to avoid recomputing the clustering step.
