# Layer 04 - Parcel Standardization

Parcel standardization remains intentionally manual-operational for geometry, but the county-grain tabular and QA products now publish upstream.

## This Slice Includes
- folder and ownership scaffold
- architecture alignment with county-grain materialization and market columns
- explicit decision to keep parcel geometry in existing `.RDS` analysis artifacts
- reuse of existing DuckDB parcel tables for tabular parcel-serving inputs where possible
- upstream publish workflow for:
  - `parcel.parcels_canonical`
  - `parcel.parcel_join_qa`
  - `parcel.parcel_lineage`
  - `parcel.retail_parcels`
  - `qa.parcel_validation_results`
  - `qa.parcel_unmapped_use_codes`

## Geometry Decision
We are not re-platforming parcel geometry into DuckDB in this first slice.

Instead:
- canonical and serving-friendly parcel attributes should come from existing DuckDB tables
- parcel geometries should continue to come from the existing `.RDS` county analysis artifacts

This keeps Section 05 compatible and avoids unnecessary geometry conversion and recomputation during the architecture transition.

## Current Inputs
- `rof_parcel.parcel_tabular_clean`
- `rof_parcel.parcel_county_load_log`
- `ref.market_county_membership`
- `ref.land_use_mapping`
- `<parcel_standardized_root>/parcel_geometry_join_qa_county_summary.rds`
- `<parcel_standardized_root>/county_outputs/*/parcel_geometries_analysis.rds`

## Current Contract
- `parcel.parcels_canonical`
  - grain: one row per `parcel_uid`
  - geometry: none in DuckDB
  - role: canonical market-scoped parcel table with normalized market geography columns plus preserved source county fields for geometry compatibility
- `parcel.parcel_join_qa`
  - grain: one row per market county
  - geometry: none in DuckDB
  - role: county-grain bridge to geometry QA artifacts and source-county metadata
- `parcel.parcel_lineage`
  - grain: one row per market county
  - geometry: none in DuckDB
  - role: county-grain operational lineage and published parcel counts
- `parcel.retail_parcels`
  - grain: one row per `parcel_uid`
  - geometry: none in DuckDB
  - role: retail-classified enrichment on top of canonical parcels

## Market Membership Rule
Market membership for parcel publishing should be driven by `ref.market_county_membership`, which itself comes from county-to-CBSA reference crosswalks.

This layer should not use a parcel geometry join to decide market membership. Geometry artifacts are preserved for downstream spatial analysis and QA only.

## Deferred
- full county automation
- canonical parcel publishing workflow
- multi-state adapter implementation
