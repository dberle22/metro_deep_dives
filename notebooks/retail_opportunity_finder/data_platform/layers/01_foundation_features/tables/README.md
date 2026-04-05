# Foundation Table Layout

This layer uses a table-owned structure.

## Convention

- Each published DuckDB table gets its own folder under `tables/`.
- `build.sql` is used when the table definition is primarily SQL.
- `build.R` is used when the table definition is primarily procedural or spatial R logic.
- `README.md` captures the table purpose, grain, current build status, and migration notes.

## Current folders

- `cbsa_features/`
- `tract_features/`
- `market_tract_geometry/`
- `market_county_geometry/`
- `market_cbsa_geometry/`
- `context_cbsa_boundary/`
- `context_county_boundary/`
- `context_places/`
- `context_major_roads/`
- `context_water/`
- `foundation_validation_results/`
- `foundation_null_rates/`

## Transition note

- Not every table has been fully migrated into table-local build assets yet.
- The folder structure is now the source-of-truth ownership map for this layer.
