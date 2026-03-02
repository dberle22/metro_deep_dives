# Parcel Standardization Workspace (Upstream of Section 05)

This folder is the dedicated preprocessing pipeline for parcel data.

Goal:
- ingest parcel CSV exports, metadata lookups, and parcel shapefiles
- standardize schema and types once
- publish reusable county-level outputs for Section 05

Section 05 analysis scripts should read from these standardized outputs, not raw county files.

## Folder layout

- `00_config.R` - path and runtime configuration
- `01_ingest_parcel_tabular.R` - CSV + metadata ingestion and normalization
- `02_prepare_parcel_geometry.R` - shapefile ingestion and geometry enrichment
- `03_publish_parcels_duckdb.R` - publish standardized artifacts to DuckDB
- `outputs/` - local standardized artifacts (`.rds`, `.gpkg`)

## Required environment variables

- `PROPERTY_TAX_ROOT`: root folder for parcel datasets across states
  (example: `/Users/.../property_taxes`).

Default derived paths:
- `${PROPERTY_TAX_ROOT}/${PROPERTY_STATE}/data` for parcel CSV + shapefiles
- `${PROPERTY_TAX_ROOT}/${PROPERTY_STATE}/docs` for metadata lookups

Optional:
- `PROPERTY_STATE`: defaults to `fl`
- `PROPERTY_DATA_ROOT`: override state data folder
- `PROPERTY_METADATA_ROOT`: override state metadata folder
- `PROPERTY_SHAPE_ROOT`: override shapefile root (defaults to data root)
- `PARCEL_STANDARDIZED_ROOT`: override output folder for standardized artifacts.
- `PARCEL_DUCKDB_PATH`: explicit DuckDB target path for publishing.
- `PARCEL_WRITE_GPKG`: set `true` to also write `.gpkg` (default `false`)
- `DATA`: used as fallback for DuckDB path (`${DATA}/duckdb/metro_deep_dive.duckdb`).

## Run order

1. `source(".../00_config.R")`
2. `source(".../01_ingest_parcel_tabular.R")`
3. `source(".../02_prepare_parcel_geometry.R")`
4. `source(".../03_publish_parcels_duckdb.R")`

## Published outputs

Local files:
- `outputs/parcel_attributes_standardized.rds`
- `outputs/county_outputs/<county_tag>/parcel_geometries_raw.rds`
- `outputs/county_outputs/<county_tag>/parcel_geometries_analysis.rds`
- `outputs/county_outputs/<county_tag>/parcel_geometry_join_qa.rds`
- `outputs/parcel_geometry_join_qa_county_summary.rds`

DuckDB tables:
- `parcel_attributes_standardized`
- `parcel_geometries_standardized`
