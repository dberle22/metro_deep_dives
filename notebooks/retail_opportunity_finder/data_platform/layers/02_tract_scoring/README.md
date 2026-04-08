# Layer 02 - Tract Scoring

This layer moves tract eligibility scoring upstream into a reusable workflow.

## Structure
- `tables/` is a flat table registry for this layer.
- Table-owned assets are named directly for the DuckDB table, for example `scoring.tract_scores.R` or `scoring.cluster_seed_tracts.md`.
- `tract_scoring_workflow.R` is the layer orchestrator that assembles shared inputs, sources table-owned builders, and publishes managed scoring outputs.
- `run_tract_scoring_layer.R` is the executable entrypoint for the layer.

## Current Products
- `scoring.tract_scores`
- `scoring.cluster_seed_tracts`

## Current State
- `scoring.tract_scores` and `scoring.cluster_seed_tracts` are now owned through table-named R assets in `tables/`.
- The layer runner now publishes a multi-market southeast scoring slice by iterating scoreable CBSAs in `FL`, `GA`, `NC`, and `SC`.
- Section 03 remains a compatibility consumer and artifact exporter, with the managed scoring table still carrying the tract component audit fields needed by downstream notebook and zone consumers.
- The single-market builder path is still preserved for zone build and section compatibility; the multi-market behavior is only used by `run_tract_scoring_layer.R`.

## QA Status
- Managed-path validation was run by executing `run_tract_scoring_layer.R` on `2026-04-06`.
- Published live outputs after rebuild:
  - `scoring.tract_scores`: `11172` rows across `117` markets / `117` CBSAs
  - `scoring.cluster_seed_tracts`: `2836` rows across `117` markets / `117` CBSAs
- Layer QA passed for:
  - multi-market publication present
  - one `cbsa_code` per `market_key`
  - zero duplicate `(market_key, tract_geoid)` keys in both published tables
  - cluster seed counts equal `ceiling(tract_score_rows * 0.25)` for every market
- The tract scoring publication retains a clean schema with a single `cbsa_code` column.

## Still Pending
- Model registry externalization
- scoring version governance
- explicit QA run tables
