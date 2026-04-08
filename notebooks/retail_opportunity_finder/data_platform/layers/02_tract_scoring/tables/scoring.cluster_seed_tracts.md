# `scoring.cluster_seed_tracts`

- Grain: one row per `market_key`, `tract_geoid`
- Published by: `tract_scoring_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/02_tract_scoring/tables/scoring.cluster_seed_tracts.R`
- Status: implemented; table-owned seed-selection builder extracted on `2026-04-06`

## Table role

- This table publishes the tract subset retained as cluster seeds for downstream zone building.
- It is derived directly from the managed tract scoring output and preserves the rank-based seed selection rule used by the current zoning workflow.
- The published table is now multi-market across the southeast scoring slice, but seed selection still happens independently within each market / CBSA.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/02_tract_scoring/tables/scoring.cluster_seed_tracts.R`
- Live `run_timestamp` range: `2026-04-06 13:57:26.382789` to `2026-04-06 13:57:40.648052`
- Live rows: `2836`
- Live distinct `market_key`: `117`
- Live distinct `cbsa_code`: `117`
- Live distinct `tract_geoid`: `2836`
- Live column count: `12`

## Live southeast seed snapshot

- `cluster_top_share`: `0.25` for every live market
- All `117` markets have live seed row counts matching `ceiling(tract_score_rows * 0.25)`
- There are `0` duplicate `(market_key, tract_geoid)` keys
- The table currently covers the same `117` markets / CBSAs as `scoring.tract_scores`

## QA notes

- The table rebuild completed successfully through `run_tract_scoring_layer.R` on `2026-04-06`.
- The published row counts match the current locked seed rule for every market in the live table.
- Section 03 checks and the zone-build readiness checks both require the current contract:
  - `tract_geoid`
  - `tract_score`
  - `cluster_seed_rank`
  - `cluster_top_share`
  - `cluster_cutoff_n`
  - `eligible_v1`

## Managed-path notes

- Seed selection is now owned by a dedicated table-named R asset instead of being embedded inline in the layer workflow.
- `build_source` now resolves to the seed table asset, which keeps lineage distinct from the main tract scoring publication.
