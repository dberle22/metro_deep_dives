# `qa.parcel_unmapped_use_codes`

- Grain: one row per unresolved `land_use_code`
- Published by: `parcel_standardization_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/qa.parcel_unmapped_use_codes.R`
- SQL companion: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/qa.parcel_unmapped_use_codes.sql`
- Status: organized; table-owned assets extracted on `2026-04-06`

## Table role

- Publishes the parcel land-use remediation backlog for the current market publication.
- Shows which `land_use_code` values are present in canonical parcels but absent from the governed mapping.

## Current managed logic

- Anti-joins canonical parcel `land_use_code` values against `ref.land_use_mapping`.
- Counts impacted parcels per unresolved code.
- Stores build metadata for QA review and governance follow-up.

## Management notes

- This table is directly downstream of `parcel.parcels_canonical`.
- It is not a duplicate of `qa.parcel_validation_results`; it is the detailed backlog behind one validation check.
