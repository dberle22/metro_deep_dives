# `zones.cluster_zone_summary`

- Grain: one row per `market_key`, `cluster_id`
- Published by: `zone_build_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/tables/zones.cluster_zone_summary.R`
- Status: implemented; table-owned summary asset extracted on `2026-04-06`

## Table role

- This is the zone-level KPI summary for the default cluster zone system.
- It is the primary cluster-system table for downstream comparisons, Section 04 narratives, and later serving use.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/03_zone_build/tables/zones.cluster_zone_summary.R`
- Live `run_timestamp` range: `2026-04-06 17:25:53.637399` to `2026-04-06 17:27:54.239736`
- Live rows: `447`
- Live distinct `market_key`: `115`
- Live distinct `cbsa_code`: `115`
- Live column count: `17`
- Live state scope coverage:
  - `FL`: `28` markets / `130` rows
  - `GA`: `36` markets / `135` rows
  - `NC`: `37` markets / `124` rows
  - `SC`: `14` markets / `58` rows

## Live multi-market snapshot

- Current live cluster zones: `447`
- Duplicate `(market_key, cluster_id)` keys: `0`

## Scope diagnosis

- This live summary is now multi-market across the `115` zone-ready southeast markets.
- It remains narrower than the full Layer 02 scoring universe by `2` markets because `cbsa_12260` and `cbsa_16740` fail zone-input readiness.
- The summary asset is appropriately general as a table-owned extractor over the cluster bundle.
- What now limits full southeast coverage is data readiness in the tract geometry handoff, not a single-market orchestration boundary.

## Managed-path notes

- This summary is now published from a table-owned extractor asset with table-specific lineage metadata.
