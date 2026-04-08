# `parcel.retail_parcels`

- Grain: one row per `parcel_uid`
- Published by: `parcel_standardization_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/archive/parcel.retail_parcels.R`
- SQL companion: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/archive/parcel.retail_parcels.sql`
- Status: organized; table-owned assets extracted on `2026-04-06`

## Table role

- Publishes the retail-only subset of the canonical parcel table.
- Gives downstream consumers a pre-filtered retail parcel universe for serving-layer work and Section 05.
- In the simplified Layer 04 design, this is a compatibility output rather than a primary modeled table.

## Current managed logic

- Reads the already-classified `parcel.parcels_canonical` result in memory.
- Filters to `retail_flag = TRUE`.
- Preserves the same parcel identity, county, value, and classification columns as canonical.

## Management notes

- This table is effectively a strict subset of `parcel.parcels_canonical`.
- It is a convenience publication rather than a distinct transformation stage.
- It should remain only until Layer 05 and Section 05 stop depending on a dedicated retail-only parcel table.
