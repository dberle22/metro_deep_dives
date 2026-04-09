# `scoring.tract_scores`

- Grain: one row per `market_key`, `tract_geoid`
- Published by: `tract_scoring_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/02_tract_scoring/tables/scoring.tract_scores.R`
- Status: implemented; table-owned scoring builder extracted on `2026-04-06`

## Table role

- This is the managed tract-level scoring output for the ROF scoring layer.
- It carries the Section 03-compatible tract score audit fields that downstream zone and notebook consumers still need during the transition.
- The published table is market-scoped, but the layer runner now materializes many markets in one pass by iterating scoreable CBSAs in the current southeast slice.
- Tracts are still scored only against other tracts in the same market / CBSA because each market run filters `foundation.tract_features` to a single `cbsa_code` before scoring.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/02_tract_scoring/tables/scoring.tract_scores.R`
- Live `run_timestamp` range: `2026-04-06 13:57:26.370002` to `2026-04-06 13:57:40.643978`
- Live rows: `11172`
- Live distinct `market_key`: `117`
- Live distinct `cbsa_code`: `117`
- Live distinct `tract_geoid`: `11172`
- Live distinct `year`: `1` (`2024`)
- Live column count: `41`

## Live southeast publication snapshot

- State split of the current publication:
  - `FL`: `5029` rows across `28` markets / CBSAs
  - `GA`: `2513` rows across `37` markets / CBSAs
  - `NC`: `2425` rows across `38` markets / CBSAs
  - `SC`: `1205` rows across `16` markets / CBSAs
- Current market-key mix:
  - `7` named market profiles from `MARKET_PROFILES`
  - `110` generated `cbsa_<code>` market keys for additional scoreable CBSAs
- Example QA check result: all `117` markets have tract-score row counts matching the underlying `foundation.tract_features` rows for their `cbsa_code`

## QA notes

- The table rebuild completed successfully through `run_tract_scoring_layer.R` on `2026-04-06`.
- The live table now has a clean published schema with a single `cbsa_code` column; the previous duplicate-name artifact was removed by the rebuild.
- Layer QA confirmed:
  - multi-market publication is present
  - each `market_key` maps to exactly one `cbsa_code`
  - there are `0` duplicate `(market_key, tract_geoid)` keys
  - all `117` markets satisfy the current `25%` seed rule when compared with `scoring.cluster_seed_tracts`
- Section 03 compatibility checks still describe the required scoring columns used by notebook consumers:
  - gates: `gate_pop`, `gate_price`, `gate_density`, `eligible_v1`
  - scoring fields: `z_*`, `contrib_*`, `tract_score`, `tract_rank`, `why_tags`, `is_scored`
- Downstream zone build still expects the Section 03-style component payload, so this table continues to double as the tract component score audit table during transition.

## Managed-path notes

- The layer now matches the foundation pattern: table-owned builder logic lives in `tables/`, while the top-level workflow acts as the orchestrator/publisher.
- `build_source` now points to the table-owned asset instead of the layer root, which makes lineage more precise for future review passes.
- The layer runner publishes a southeast multi-market scoring slice, while `build_tract_scoring_products()` still supports the single-market compatibility path used by zone build.
