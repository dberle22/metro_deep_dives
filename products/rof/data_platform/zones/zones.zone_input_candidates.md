# `zones.zone_input_candidates`

- Grain: one row per `market_key`, `tract_geoid`
- Published by: `zone_build_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/tables/zones.zone_input_candidates.R`
- Status: implemented; table-owned zone-candidate builder extracted on `2026-04-06`

## Table role

- This table is the geometry-bearing tract candidate universe for zone construction.
- It is the bridge between Layer 02 scoring outputs and the contiguity / cluster zone builders.
- The current live table remains single-market because Layer 03 still runs one active market profile at a time.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/03_zone_build/tables/zones.zone_input_candidates.R`
- Live `run_timestamp` range: `2026-04-06 17:25:53.509945` to `2026-04-06 17:27:53.907347`
- Live rows: `2629`
- Live distinct `market_key`: `115`
- Live distinct `cbsa_code`: `115`
- Live column count: `11`
- Live southeast market coverage vs current Layer 02 scoring universe: `115` of `117` scoreable market profiles
- Live state scope coverage:
  - `FL`: `28` markets / `1267` rows
  - `GA`: `36` markets / `615` rows
  - `NC`: `37` markets / `475` rows
  - `SC`: `14` markets / `272` rows

## Live multi-market snapshot

- Candidate row count matches the published zone-ready cluster-seed tract slice for the `115` published markets.
- Duplicate `(market_key, tract_geoid)` keys: `0`
- The table carries `tract_score`, `tract_rank`, `eligible_v1`, `zone_candidate`, and `geom_wkt` for every candidate tract.

## Scope diagnosis

- This table is now multi-market for the current southeast tract-available slice.
- It is not yet built for all `117` scoreable southeast CBSAs because `2` markets still fail zone-input readiness:
  - `cbsa_12260` (`GA`): `23` cluster-seed tracts missing from tract geometry
  - `cbsa_16740` (`NC`): `30` cluster-seed tracts missing from tract geometry
- The updated Layer 03 runner no longer republishes Layer 02. It reads the published multi-market `scoring.tract_scores` and `scoring.cluster_seed_tracts` tables, enriches the scoring slice with `pop_total` from `foundation.tract_features`, reconstructs per-market tract geometry, and publishes the combined `zones.*` outputs in one pass.
- The table-owned `.R` asset remains the right management target because the logic is procedural and geometry-bearing.

## Managed-path notes

- The zone-input readiness and set-consistency checks now live in a dedicated table-owned R asset.
- The live table has been rebuilt with a table-specific `build_source` instead of the generic layer root path.
- Layer 03 now uses the readiness checks operationally to skip markets that are not yet zone-ready instead of collapsing the whole publication back to one active market.
