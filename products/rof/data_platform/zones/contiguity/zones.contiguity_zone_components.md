# `zones.contiguity_zone_components`

- Grain: one row per `market_key`, `tract_geoid`
- Published by: `zone_build_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/tables/zones.contiguity_zone_components.R`
- Status: implemented; table-owned contiguity builder extracted on `2026-04-06`

## Table role

- This is the tract-to-component assignment table for the strict contiguity zone system.
- It assigns each candidate tract to a touching-based connected component and preserves the draft component label used downstream.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/03_zone_build/tables/zones.contiguity_zone_components.R`
- Live `run_timestamp` range: `2026-04-06 17:25:53.575894` to `2026-04-06 17:27:54.10434`
- Live rows: `2629`
- Live distinct `market_key`: `115`
- Live distinct `cbsa_code`: `115`
- Live column count: `9`
- Live state scope coverage:
  - `FL`: `28` markets / `1267` rows
  - `GA`: `36` markets / `615` rows
  - `NC`: `37` markets / `475` rows
  - `SC`: `14` markets / `272` rows

## Live multi-market snapshot

- Candidate tracts assigned to contiguity components: `2629`
- Downstream contiguity summary/geometries resolve to `749` contiguity zones in the current live slice.
- Duplicate `(market_key, tract_geoid)` keys: `0`

## Scope diagnosis

- This table is now a southeast multi-market publication for the `115` zone-ready markets in `FL`, `GA`, `NC`, and `SC`.
- It skips the same `2` markets flagged by the zone-input readiness checks because their cluster-seed tracts are not fully covered by tract geometry.
- The contiguity asset itself remains general for one market slice; the orchestration now loops that asset across the ready market set and publishes the combined output.

## Managed-path notes

- The touching-graph and connected-components logic now lives in the table-owned contiguity asset.
- Summary and geometry outputs still reuse the same in-memory contiguity bundle so we do not recompute spatial adjacency three times.
