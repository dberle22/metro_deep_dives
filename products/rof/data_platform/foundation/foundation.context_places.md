# `foundation.context_places`

- Grain: varies by source geometry
- Transitional source script: `notebooks/retail_opportunity_finder/sections/02_market_overview/context_layers/01_ingest_context_layers.R`
- Transitional reader asset: `notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features/tables/foundation.context_places.R`
- Current source object: `notebooks/retail_opportunity_finder/sections/02_market_overview/context_layers/outputs/section_02_context_places_sf.rds`
- Status: transitional context object; managed as cached R artifact rather than a required DuckDB table

## Current object snapshot

- Profiled on: `2026-04-06`
- Source mode: `tigris_only`
- Target CBSA: `27260`
- Target year: `2024`
- Rows: `37`
- Attribute columns: `14`
- Geometry types: `POLYGON`, `MULTIPOLYGON`
- Key fields present: `place_geoid`, `place_name`, `name`, `statefp`, `placefp`
- Bounding box: `xmin -82.1670`, `ymin 29.6227`, `xmax -81.2130`, `ymax 30.7072`

## Management notes

- This object provides municipal boundary context for visuals and should remain an R-side cached artifact unless there is a stronger product need.
- The saved object lives in the legacy `context_layers/outputs/` path rather than the standard market-keyed artifact location.
- The current saved object currently has undefined EPSG metadata even though the ingest script transforms layers to the expected mapping CRS.
