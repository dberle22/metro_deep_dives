# `foundation.context_cbsa_boundary`

- Grain: varies by source geometry
- Transitional source script: `notebooks/retail_opportunity_finder/sections/02_market_overview/context_layers/01_ingest_context_layers.R`
- Transitional reader asset: `notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features/tables/foundation.context_cbsa_boundary.R`
- Current source object: `notebooks/retail_opportunity_finder/sections/02_market_overview/context_layers/outputs/section_02_context_cbsa_boundary_sf.rds`
- Status: transitional context object; managed as cached R artifact rather than a required DuckDB table

## Current object snapshot

- Profiled on: `2026-04-06`
- Source mode: `tigris_only`
- Target CBSA: `27260`
- Target year: `2024`
- Rows: `1`
- Attribute columns: `2` (`cbsa_code`, `cbsa_name`)
- Geometry type: `POLYGON`
- Bounding box: `xmin -82.4598`, `ymin 29.6224`, `xmax -81.2129`, `ymax 30.8299`

## Management notes

- This object is a lightweight context artifact for maps, not a core analytical table.
- The current saved object lives in the legacy `context_layers/outputs/` path rather than the standard market-keyed artifact location.
- The saved object currently has undefined EPSG metadata even though the ingest script transforms layers to the expected mapping CRS.
