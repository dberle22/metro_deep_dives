# Layer 04 - Parcel Standardization

Parcel standardization remains intentionally manual-operational for geometry, but the county-grain tabular and QA products now publish upstream as stable multi-market data-platform tables.

## This Slice Includes
- folder and ownership scaffold
- table-owned parcel build assets under `tables/`
- state-owned manual parcel ETL scripts under `state_scripts/`
- architecture alignment with county-grain materialization and market columns
- explicit decision to keep parcel geometry in existing `.RDS` analysis artifacts
- reuse of existing DuckDB parcel tables for tabular parcel-serving inputs where possible
- multi-market publication across all parcel-backed ROF markets instead of active-market overwrites
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
  - role: canonical parcel table across all parcel-backed ROF markets with normalized market geography columns plus preserved source county fields for geometry compatibility
- `parcel.parcel_join_qa`
  - grain: one row per parcel-backed market county
  - geometry: none in DuckDB
  - role: county-grain bridge to geometry QA artifacts and source-county metadata
- `parcel.parcel_lineage`
  - grain: one row per parcel-backed market county
  - geometry: none in DuckDB
  - role: county-grain operational lineage and published parcel counts
- `parcel.retail_parcels`
  - grain: one row per `parcel_uid`
  - geometry: none in DuckDB
  - role: retail-classified enrichment on top of canonical parcels

## Market Membership Rule
Market membership for parcel publishing should be driven by `ref.market_county_membership`, constrained to counties that actually have parcel tabular coverage in `rof_parcel.parcel_tabular_clean`.

This layer should not use a parcel geometry join to decide market membership. Geometry artifacts are preserved for downstream spatial analysis and QA only.

The publish scope is therefore:
- all ROF markets present in `ref.market_county_membership`
- intersected with counties that have parcel data available upstream

Layer 04 should publish that whole available parcel-market scope in one stable run. Notebook sections should query these tables; they should not require a per-market rebuild of Layer 04.

## Deferred
- full county automation
- canonical parcel publishing workflow
- multi-state adapter implementation

## State Script Ownership
Layer 04 owns the heavy end-to-end parcel ETL scripts even when they remain manual and state-specific.

Current state scripts:
- `state_scripts/fl_parcel_etl_manual_county.R`
  - Florida manual county ETL and QA workflow
  - intentionally not refactored into table-owned assets because it is the operational E2E path for Florida parcels
  - expected long-term pattern is one manual script per state when state source systems require different handling

## Managed Table Assets

Layer 04 now also has table-owned organizational assets under `tables/` for:
- `parcel.parcels_canonical`
- `parcel.parcel_lineage`
- `qa.parcel_validation_results`
- `qa.parcel_unmapped_use_codes`

Historical compatibility table assets now live under `tables/archive/`:
- `parcel.parcel_join_qa`
- `parcel.retail_parcels`

These files were extracted for organization only in this pass. No tables were rebuilt, and the `.sql` files are companion placeholders rather than active execution paths.

## Concrete Layer 04 Shape

Layer 04 now treats the following as the primary managed products:
- `parcel.parcels_canonical`
- `parcel.parcel_lineage`
- `qa.parcel_validation_results`
- `qa.parcel_unmapped_use_codes`

Compatibility outputs are still published for downstream consumers that have not yet been refactored:
- `parcel.retail_parcels`
  - compatibility subset of `parcel.parcels_canonical` filtered to `retail_flag = TRUE`
- `parcel.parcel_join_qa`
  - compatibility county QA projection derived from `parcel.parcel_lineage`

This keeps Layer 04 simpler internally while preserving the current contracts for Layer 05 and Section 05.
