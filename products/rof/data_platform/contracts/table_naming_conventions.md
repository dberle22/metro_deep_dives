# Table Naming Conventions

## Pattern
Use `schema.table_name` with snake case and grain-explicit nouns.

## Naming Rules
- Prefer the business grain in the noun:
  - `tract_scores`
  - `cluster_seed_tracts`
  - `cluster_zone_summary`
- Use suffixes to distinguish product types:
  - `_summary`: one row per business entity summary.
  - `_geometries`: geometry-bearing serving table.
  - `_assignments`: membership or bridge table.
  - `_manifest`: ingest or batch manifest.
  - `_qa`: validation or QA product.
- Avoid notebook-section prefixes in DuckDB table names.
- Reserve `section_XX_*` naming for legacy artifact compatibility only.

## Grain Expectations
- Tract-level tables: one row per `market_key`, `tract_geoid`.
- Zone assignment tables: one row per `market_key`, `tract_geoid`, `zone_method`.
- Zone summary tables: one row per `market_key`, `zone_method`, `zone_id`.
- Geometry tables: one row per `market_key`, `zone_method`, `zone_id`.
- County parcel-serving tables: one row per parcel per county, with market columns attached for stitching.

## Initial Method Labels
- `zone_method = 'contiguity'`
- `zone_method = 'cluster'`
