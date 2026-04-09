# `qa.zone_build_validation_results`

- Grain: one row per QA check
- Published by: `zone_build_workflow.R`
- Managed build asset: Layer-owned QA builder inside `notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/zone_build_workflow.R`
- Status: implemented; published with Layer 03 on `2026-04-06`

## Table role

- This table is the structured QA summary for Layer 03.
- It records whether the published `zones.*` slice is multi-market, whether all target states are represented, whether grain keys remain unique, whether summary and geometry outputs stay aligned, and whether any markets were skipped during readiness checks.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live rows: `18`
- Live passing checks: `17`
- Live failing checks: `1`
- Failing check severity: warning-only
- Live `run_timestamp`: `2026-04-06 17:44:42.697765`
- Live `build_source`: `data_platform/layers/03_zone_build`

## Current findings

- The `17` error-severity checks are all passing.
- The only failing row is the warning check for skipped markets.
- The current QA confirms:
  - `115` published markets
  - all target state scopes present: `FL`, `GA`, `NC`, `SC`
  - published plus skipped markets reconcile to the `117`-market Layer 02 southeast scoring universe
  - zero duplicate grain keys across the published `zones.*` tables
  - contiguity summary/geometries and cluster summary/geometries remain row-aligned and market-aligned

## Management notes

- This table makes Layer 03 operationally auditable without requiring log inspection.
- The remaining warning is expected until the skipped-market tract-geometry gaps are resolved.
