# Layer 03 - Zone Build

This layer moves contiguity and cluster zone construction upstream.

## Structure
- `tables/` is a flat table registry for this layer.
- Table-owned assets are named directly for the DuckDB table, for example `zones.cluster_assignments.R` or `zones.cluster_zone_summary.md`.
- `zone_build_workflow.R` is the layer orchestrator that sources table-owned assets and publishes the managed zone outputs.
- `run_zone_build_layer.R` is the executable entrypoint for the layer.

## Current Products
- `zones.zone_input_candidates`
- `zones.contiguity_zone_components`
- `zones.contiguity_zone_summary`
- `zones.contiguity_zone_geometries`
- `zones.cluster_assignments`
- `zones.cluster_zone_summary`
- `zones.cluster_zone_geometries`
- `qa.zone_build_validation_results`
- `qa.zone_build_skipped_markets`

## Current State
- All seven `zones.*` products are now owned through table-named R assets in `tables/`.
- Section 04 continues to consume the same workflow functions, so the compatibility path is preserved while the table ownership becomes explicit.
- Layer 03 now publishes a multi-market southeast zone slice for the states where tract geometry is currently zone-ready.
- The current live `zones.*` tables contain `115` markets / CBSAs across `FL`, `GA`, `NC`, and `SC`.
- The updated runner reads the published multi-market Layer 02 scoring tables and no longer republishes or overwrites `scoring.*`.
- The orchestration is now general at the market-loop level: it iterates the resolved southeast scoring profiles, reconstructs the needed per-market tract geometry slice, builds zone products market by market, and publishes the combined zone slice in one pass.

## QA Status
- Managed-path validation was run by executing `run_zone_build_layer.R` on `2026-04-06`.
- Published live outputs after rebuild:
  - `zones.zone_input_candidates`: `2629` rows
  - `zones.contiguity_zone_components`: `2629` rows
  - `zones.contiguity_zone_summary`: `749` rows
  - `zones.contiguity_zone_geometries`: `749` rows
  - `zones.cluster_assignments`: `2629` rows
  - `zones.cluster_zone_summary`: `447` rows
  - `zones.cluster_zone_geometries`: `447` rows
- Live market / CBSA coverage after validation: `115` markets / `115` CBSAs
- State coverage after validation:
  - `FL`: `28` markets
  - `GA`: `36` markets
  - `NC`: `37` markets
  - `SC`: `14` markets
- Comparison point from the Layer 02 southeast scoring universe: `117` scoreable market profiles across `FL`, `GA`, `NC`, and `SC`, of which Layer 03 currently publishes `115`
- Skipped markets during zone-build validation:
  - `cbsa_12260` (`12260`, `GA`): `23` cluster-seed tracts missing from tract geometry
  - `cbsa_16740` (`16740`, `NC`): `30` cluster-seed tracts missing from tract geometry
- The live `build_source` metadata for all zone tables now points at the table-owned assets.
- Duplicate-key spot checks after rebuild:
  - `zones.zone_input_candidates`: `0` duplicate `(market_key, tract_geoid)` keys
  - `zones.contiguity_zone_components`: `0` duplicate `(market_key, tract_geoid)` keys
  - `zones.contiguity_zone_summary`: `0` duplicate `(market_key, zone_id)` keys
  - `zones.contiguity_zone_geometries`: `0` duplicate `(market_key, zone_id)` keys
  - `zones.cluster_assignments`: `0` duplicate `(market_key, tract_geoid)` keys
  - `zones.cluster_zone_summary`: `0` duplicate `(market_key, cluster_id)` keys
  - `zones.cluster_zone_geometries`: `0` duplicate `(market_key, cluster_id)` keys
- QA tables now published:
  - `qa.zone_build_validation_results`: `18` rows (`17` passing checks, `1` warning-only failing check for skipped markets)
  - `qa.zone_build_skipped_markets`: `2` rows

## Still Pending
- follow-up on the two skipped CBSAs where cluster-seed tracts are missing from tract geometry
- independent runner integration
- serving-layer handoff into parcel prep
