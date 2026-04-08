# `parcel.parcel_lineage`

- Grain: one row per `market_key`, `county_geoid`
- Published by: `parcel_standardization_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/parcel.parcel_lineage.R`
- SQL companion: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/parcel.parcel_lineage.sql`
- Status: organized; table-owned assets extracted on `2026-04-06`

## Table role

- Publishes county-level operational lineage for the parcel layer.
- Combines parcel publication counts, county load-log metadata, and geometry QA lineage into one audit view.
- Supports debugging and ops review of which county inputs fed the current multi-market publication.
- In the simplified Layer 04 design, this is the primary county-grain operational table.

## Current managed logic

- Starts from parcel-backed market counties in `ref.market_county_membership`.
- Brings in parcel geometry QA artifact metadata when present.
- Adds the latest available `rof_parcel.parcel_county_load_log` metadata per county where available.
- Aggregates parcel counts from `parcel.parcels_canonical`.
- Coalesces those sources into one county-level lineage record.

## Management notes

- This table materially overlaps with `parcel.parcel_join_qa`.
- `parcel.parcel_join_qa` is now treated as a compatibility projection from this broader county-level table.
