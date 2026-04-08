# `qa.parcel_validation_results`

- Grain: one row per QA check
- Published by: `parcel_standardization_workflow.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/qa.parcel_validation_results.R`
- SQL companion: `notebooks/retail_opportunity_finder/data_platform/layers/04_parcel_standardization/tables/qa.parcel_validation_results.sql`
- Status: organized; table-owned assets extracted on `2026-04-06`

## Table role

- Publishes the parcel-layer QA summary for Layer 04.
- Aggregates key uniqueness, parcel-backed county coverage, geometry QA readiness, and unmapped-use-code checks into one build-validation table.

## Current managed logic

- Validates `parcel_uid` uniqueness in `parcel.parcels_canonical`.
- Checks missing `join_key` and missing `county_geoid`.
- Reads the unresolved-code backlog from `qa.parcel_unmapped_use_codes`.
- Checks missing or failed county geometry QA lineage in `parcel.parcel_join_qa`.
- Flags counties with zero published parcels in `parcel.parcel_lineage`.

## Management notes

- This table is a summary layer over other Layer 04 outputs rather than an independent data product.
- It should remain separate from `qa.parcel_unmapped_use_codes` because one is a rollup and the other is a detailed remediation backlog.
