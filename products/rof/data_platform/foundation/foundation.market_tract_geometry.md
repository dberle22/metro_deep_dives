# `foundation.market_tract_geometry`

- Grain: one row per `cbsa_code`, `tract_geoid`
- Published by: `foundation_feature_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features/tables/foundation.market_tract_geometry.sql`
- Status: implemented; generalized to a CBSA-keyed publication over the current upstream tract backbone on `2026-04-06`

## Table role

- CBSA-keyed tract geometry service published in DuckDB-friendly `geom_wkt` form.
- Downstream consumers should filter by `cbsa_code` rather than relying on a market-scoped geometry publication.
- This table should remain a serving table for metro-linked tracts, not the canonical all-tract geometry store.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/01_foundation_features/tables/foundation.market_tract_geometry.sql`
- Live `run_timestamp`: `2026-04-06 10:45:15.865954`
- Live rows: `10020`
- Live distinct `cbsa_code`: `106`
- Live distinct `tract_geoid`: `10020`
- Live distinct `county_geoid`: `229`
- Live duplicate `(cbsa_code, tract_geoid)` rows: `0`
- Live column count: `7`

## Jacksonville slice

- Jacksonville (`27260`) rows: `340`
- Example rows confirm expected keys and geometry payload for `tract_geoid`, `county_geoid`, `state_fips`, and `geom_wkt`

## Important findings

- The prior market-scoped publication has been replaced with a generalized CBSA-keyed tract geometry table.
- The generalized table currently covers the same `106` CBSA-linked tract set as `foundation.tract_features`.
- Tracts with missing `cbsa_code` in `foundation.tract_features` are not published here because this table keys directly on tract-to-CBSA membership.
- Current upstream geometry source is still `metro_deep_dive.geo.tracts_supported_states`.
- Target upstream geometry design is `metro_deep_dive.geo.tracts_all_us` as the canonical all-tract source, with this table staying downstream and CBSA-keyed.
