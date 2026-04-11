# `foundation.market_county_geometry`

- Grain: one row per `cbsa_code`, `county_geoid`
- Published by: `foundation_feature_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features/tables/foundation.market_county_geometry.sql`
- Status: implemented; generalized to national publication on `2026-04-06`

## Table role

- National county geometry service published in DuckDB-friendly `geom_wkt` form for all CBSA-linked counties.
- Downstream consumers should filter by `cbsa_code` rather than relying on a market-scoped county publication.

## Current live DuckDB snapshot

- Profiled on: `2026-04-06`
- DuckDB table exists: `Yes`
- Live `build_source`: `data_platform/layers/01_foundation_features/tables/foundation.market_county_geometry.sql`
- Live `run_timestamp`: `2026-04-06 10:45:15.868674`
- Live rows: `1915`
- Live distinct `cbsa_code`: `935`
- Live distinct `county_geoid`: `1915`
- Live duplicate `(cbsa_code, county_geoid)` rows: `0`
- Live column count: `7`

## Jacksonville slice

- Jacksonville (`27260`) county rows: `5`
- Example counties: `12003` Baker, `12019` Clay, `12031` Duval

## Important findings

- The prior market-scoped county geometry handoff has been replaced with a generalized national county geometry table.
- County geometry now aligns to CBSA-linked county membership rather than to the active market only.
