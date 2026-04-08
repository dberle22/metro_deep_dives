# `parcel.parcels_canonical`

- Grain: one row per `parcel_uid`
- Published by: `parcel_standardization_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/parcel.parcels_canonical.R`
- SQL companion: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/parcel.parcels_canonical.sql`
- Status: organized; table-owned assets extracted on `2026-04-06`

## Table role

- Publishes the stable multi-market canonical parcel attribute table without geometry.
- Filters `rof_parcel.parcel_tabular_clean` to parcel-backed county membership from `ref.market_county_membership`.
- Normalizes county and parcel identifiers, coerces parcel value fields, and derives `parcel_uid`.
- Attaches governed retail classification fields upstream so downstream consumers can read one enriched canonical parcel table.

## Current managed logic

- Reads all parcel-backed market counties from `ref.market_county_membership`.
- Reads parcel tabular rows from `rof_parcel.parcel_tabular_clean`.
- Normalizes `county_fips`, `county_code`, `land_use_code`, and county-name join keys.
- Derives parcel lineage and QA flags including `qa_missing_join_key` and `qa_zero_county`.
- Deduplicates to one row per `parcel_uid` across the combined publish while preserving a duplicate profile for QA.

## Management notes

- Geometry is intentionally excluded from DuckDB in this layer.
- The current county filter still depends on source `county_name` alignment plus county reference membership.
- The published table already carries retail classification columns, which makes it the primary parcel-grain table in the simplified Layer 04 design.
- `parcel.retail_parcels` is retained only as a downstream compatibility subset (DEPRECATED - use this table with retail_flag = TRUE instead).
