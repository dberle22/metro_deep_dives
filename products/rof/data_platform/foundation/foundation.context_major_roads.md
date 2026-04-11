# `foundation.context_major_roads`

- Grain: varies by source geometry
- Transitional source script: `notebooks/retail_opportunity_finder/sections/02_market_overview/context_layers/01_ingest_context_layers.R`
- Transitional reader asset: `notebooks/retail_opportunity_finder/data_platform/layers/01_foundation_features/tables/foundation.context_major_roads.R`
- Current source object: `notebooks/retail_opportunity_finder/sections/02_market_overview/context_layers/outputs/section_02_context_major_roads_sf.rds`
- Status: transitional context object; managed as cached R artifact rather than a required DuckDB table

## Current object snapshot

- Profiled on: `2026-04-06`
- Source mode: `tigris_only`
- Target CBSA: `27260`
- Target year: `2024`
- Rows: `778`
- Attribute columns: `4` (`LINEARID`, `FULLNAME`, `RTTYP`, `MTFCC`)
- Geometry types: `POINT`, `LINESTRING`, `MULTILINESTRING`
- Bounding box: `xmin -82.4594`, `ymin 29.6513`, `xmax -81.2138`, `ymax 30.7766`

## Management notes

- This object is a rendering helper for major-road context and should remain an R-side cached artifact unless there is a clear need for governed tabular publication.
- The mixed geometry types are worth keeping in mind for downstream rendering assumptions.
- The saved object lives in the legacy `context_layers/outputs/` path rather than the standard market-keyed artifact location.
