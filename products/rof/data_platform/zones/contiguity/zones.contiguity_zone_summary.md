# `zones.contiguity_zone_summary`

- Grain: one row per `market_key`, `zone_id`
- Published by: `zone_build_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/03_zone_build/tables/zones.contiguity_zone_summary.R`
- Status: implemented; table-owned summary asset extracted on `2026-04-06`

## Table role

- This table summarizes each touching-based contiguity zone into an operational zone KPI row.
- It is the primary contiguity-system summary handoff for downstream review and comparison.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/03_zone_build/tables/zones.contiguity_zone_summary.R`
- Live `run_timestamp` range: `2026-04-06 17:25:53.581483` to `2026-04-06 17:27:54.108349`
- Live rows: `749`
- Live distinct `market_key`: `115`
- Live distinct `cbsa_code`: `115`
- Live column count: `23`
- Live state scope coverage:
  - `FL`: `28` markets / `283` rows
  - `GA`: `36` markets / `199` rows
  - `NC`: `37` markets / `171` rows
  - `SC`: `14` markets / `96` rows

## Live multi-market snapshot

- Current live contiguity zones: `749`
- Duplicate `(market_key, zone_id)` keys: `0`

## Scope diagnosis

- This live summary is now multi-market for the current southeast zone-ready slice.
- It is published for `115` markets / CBSAs, with the same `2` skipped markets carried as QA findings rather than hidden by a single-market overwrite.
- The summary asset itself remains appropriately general because it just returns the contiguity bundle's summary table.

## Managed-path notes

- This summary is now published from a table-owned extractor asset, while the heavier contiguity spatial logic remains shared through the contiguity bundle.
