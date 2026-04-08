# `parcel.parcel_join_qa`

- Grain: one row per `market_key`, `county_geoid`
- Published by: `parcel_standardization_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/archive/parcel.parcel_join_qa.R`
- SQL companion: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/archive/parcel.parcel_join_qa.sql`
- Status: organized; table-owned assets extracted on `2026-04-06`

## Table role

- Bridges market counties to county-level parcel geometry QA artifacts.
- Tells downstream consumers which county analysis artifacts exist and whether county geometry joins passed QA.
- Preserves county-grain readiness metadata without moving parcel geometry into DuckDB.
- In the simplified Layer 04 design, this is now a compatibility output rather than a primary build target.

## Current managed logic

- Projects the QA-focused county fields out of `parcel.parcel_lineage`.
- Preserves the existing county readiness contract for downstream consumers.

## Management notes

- This table is a bridge to disk artifacts, not a geometry table itself.
- It overlaps with `parcel.parcel_lineage` on county-level operational metadata.
- It is intentionally retained only as a downstream compatibility table until later layers are refactored.
