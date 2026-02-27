# Section 05 Parcel Standardization Pipeline

This is the single canonical strategy + runbook for Section 05 parcel preprocessing.

## 1) Purpose and Scope

This pipeline standardizes parcel tabular and geometry inputs before the Retail Opportunity Finder Section 05 analysis.

It produces county-level artifacts that are:
- reproducible
- performance-aware
- auditable (raw + analysis outputs)

Section 05 should consume standardized outputs, not raw county exports.

## 2) Inputs and Environment

Primary root:
- `PROPERTY_TAX_ROOT`

Default derived paths:
- `${PROPERTY_TAX_ROOT}/${PROPERTY_STATE}/data`
- `${PROPERTY_TAX_ROOT}/${PROPERTY_STATE}/docs`

Optional overrides:
- `PROPERTY_STATE` (default `fl`)
- `PROPERTY_DATA_ROOT`
- `PROPERTY_METADATA_ROOT`
- `PROPERTY_SHAPE_ROOT` (defaults to state `data` folder)
- `PARCEL_STANDARDIZED_ROOT`
- `PARCEL_DUCKDB_PATH`
- `PARCEL_WRITE_GPKG` (`false` by default)

## 3) Canonical Schema and Mapping Rules

Tabular key rules:
- `join_key = coalesce(parcel_id, alt_key)` after trim + uppercase normalization

Field mapping decisions:
- `use_code` from `DOR_UC` (fallbacks still supported)
- `sale_qual_code` from `QUAL_CD1`, fallback `QUAL_CD2`
- county lookup join: parcel `county` -> metadata `county_number`
- sales qualification lookup join: parcel `sale_qual_code` -> metadata `code`

## 4) Pipeline Steps

### Step 1: Tabular standardization

Script:
- `parcel_standardization/01_ingest_parcel_tabular.R`

Outputs:
- `parcel_attributes_standardized.rds`

Behavior:
- ingest all parcel CSVs
- normalize core columns/types
- enrich from metadata lookup files

### Step 2: County geometry standardization

Script:
- `parcel_standardization/02_prepare_parcel_geometry.R`

Behavior:
- enumerate shapefiles under shape root
- process each shapefile independently (no full-state geometry stack)
- derive `join_key` from `PARCEL_ID` / `ALT_KEY`
- reproject to EPSG 4326 when possible
- trim attribute table before join to reduce join payload

Duplicate handling per county:
1. split valid-key vs missing-key records
2. count duplicates by `(source_shp, CO_NO, join_key)`
3. keep single-key geometries unchanged
4. aggregate duplicate-key geometries to one row per key (`do_union = FALSE`)
5. append missing-key rows back as flagged records
6. join attributes to raw + analysis geometry sets

Outputs per county:
- `county_outputs/<county_tag>/parcel_geometries_raw.rds`
- `county_outputs/<county_tag>/parcel_geometries_analysis.rds`
- `county_outputs/<county_tag>/parcel_geometry_join_qa.rds`

Summary output:
- `parcel_geometry_join_qa_county_summary.rds`

### Step 3: Optional publish step

Script:
- `parcel_standardization/03_publish_parcels_duckdb.R`

Behavior:
- publish attributes + analysis geometry to DuckDB
- consolidate county analysis files if a monolithic analysis file does not exist

## 5) Output Contract for Section 05

Primary analysis input:
- `county_outputs/<county_tag>/parcel_geometries_analysis.rds`

Audit/troubleshooting input:
- `county_outputs/<county_tag>/parcel_geometries_raw.rds`

Usage guidance:
- parcel counting should use `n_distinct(join_key)` where appropriate
- use flags to control inclusion:
  - `qa_missing_join_key`
  - `qa_zero_county`

## 6) QA Policy and Thresholds

Per-county QA includes:
- `total_rows_raw`
- `unmatched_rows_raw`
- `unmatched_rate_raw`
- `total_rows_analysis`
- `unmatched_rows_analysis`
- `unmatched_rate_analysis`

Threshold:
- warn when `unmatched_rate_raw > 1%`

Policy:
- keep unmatched rows in outputs
- flag and monitor via county QA summary

## 7) Performance Strategy

Implemented optimizations:
1. county-by-county processing instead of statewide geometry stacking
2. duplicate dissolve only for duplicate-key groups
3. trimmed attribute join payload
4. county-level artifacts for restartability and lower rerun cost

Future optimizations:
1. bounded parallel county processing
2. file-hash caching to skip unchanged counties
3. long-term indexed storage in SQL/PostGIS

## 8) Runbook

Run tabular + geometry:

```bash
PROPERTY_TAX_ROOT="/Users/<you>/Documents/projects/data/property_taxes" \
PROPERTY_STATE="fl" \
PARCEL_STANDARDIZED_ROOT="notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization/outputs/fl_all_v2" \
Rscript notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization/01_ingest_parcel_tabular.R

PROPERTY_TAX_ROOT="/Users/<you>/Documents/projects/data/property_taxes" \
PROPERTY_STATE="fl" \
PROPERTY_SHAPE_ROOT="/Users/<you>/Documents/projects/data/property_taxes/fl/data" \
PARCEL_STANDARDIZED_ROOT="notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization/outputs/fl_all_v2" \
Rscript notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization/02_prepare_parcel_geometry.R
```

Optional publish:

```bash
PROPERTY_TAX_ROOT="/Users/<you>/Documents/projects/data/property_taxes" \
PROPERTY_STATE="fl" \
PARCEL_STANDARDIZED_ROOT="notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization/outputs/fl_all_v2" \
PARCEL_DUCKDB_PATH="<path-to-duckdb>" \
Rscript notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization/03_publish_parcels_duckdb.R
```

## 9) Document Status

This file is the single source of truth and replaces overlapping guidance previously spread across:
- `parcel_data_pipeline.md`
- `parcel_data_ingestion_and_enrichment.md`
