# `qa.zone_build_skipped_markets`

- Grain: one row per skipped market / CBSA
- Published by: `zone_build_workflow.R`
- Managed build asset: Layer-owned QA builder inside `notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/zone_build_workflow.R`
- Status: implemented; published with Layer 03 on `2026-04-06`

## Table role

- This table records markets that were excluded from the live Layer 03 publication because zone-input readiness checks failed.
- It preserves the gap counts that explain why a market was skipped, rather than burying those details in runner logs.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live rows: `2`
- Live distinct `market_key`: `2`
- Live distinct `cbsa_code`: `2`
- Live `run_timestamp`: `2026-04-06 17:44:42.6996`
- Live `build_source`: `data_platform/layers/03_zone_build`

## Current skipped markets

- `cbsa_12260` (`12260`, `GA`)
  - `146` scored rows
  - `96` tract geometry rows
  - `37` cluster-seed tracts in scoring
  - `14` cluster-seed tracts in geometry
  - `23` scored cluster-seed tracts missing from tract geometry
- `cbsa_16740` (`16740`, `NC`)
  - `677` scored rows
  - `589` tract geometry rows
  - `170` cluster-seed tracts in scoring
  - `140` cluster-seed tracts in geometry
  - `30` scored cluster-seed tracts missing from tract geometry

## Management notes

- These are currently warning-level skips, not silent failures.
- Once the tract-geometry gaps are resolved, this table should drop to zero rows and the corresponding warning in `qa.zone_build_validation_results` should pass.
