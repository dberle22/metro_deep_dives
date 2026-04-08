# DuckDB Schema Contract

This document defines the initial ROF V2 schema boundary inside the project DuckDB.

## Required Schemas
- `raw_ext`: externally landed source snapshots and raw extracts.
- `ref`: stable dimensions, market membership tables, and conformed reference mappings.
- `foundation`: tract- and metro-level feature products consumed by scoring and notebook modules.
- `scoring`: tract scoring outputs, cluster seed membership, and scoring run metadata.
- `zones`: tract-to-zone assignments, zone summaries, and zone geometry serving products.
- `parcel`: canonical parcel outputs and parcel QA products.
- `serving`: notebook-ready market products and stitched county outputs.
- `qa`: validation summaries, row-count checks, lineage checkpoints, and run audit tables.

## Initial Ownership
- `foundation`: upstream feature service, not notebook sections.
- `scoring`: upstream tract scoring workflow in `data_platform/layers/02_tract_scoring/`.
- `zones`: upstream zone build workflow in `data_platform/layers/03_zone_build/`.
- `parcel`: upstream parcel standardization workflow in `data_platform/layers/04_parcel_standardization/`.
- `serving`: future market serving prep workflow.

## Geometry Storage Contract
- Zone and tract analytical geometry tables may store `geom_wkt` as the initial compatibility format.
- Parcel standardization is different in the first slice:
  - parcel tabular serving products should live in DuckDB
  - parcel geometries remain in the existing `.RDS` analysis artifacts
- Geometry-bearing serving tables must also include grain keys and market columns where geometry is stored in DuckDB.
- Downstream R modules may reconstruct `sf` objects from `geom_wkt` for zone products until direct DuckDB spatial publication is standardized.

## Market Columns
Every market-aware prepared product should carry:
- `market_key`
- `cbsa_code`
- `state_scope`
- `build_source`
- `run_timestamp`

## Standard Run Metadata Fields
These are the standard metadata fields for the V2 platform transition. Not every first-slice table carries all of them yet, but this is the target contract.

- `run_id`
- `run_ts`
- `market_key`
- `state_abbr`
- `county_fips`
- `model_id`
- `model_version`
- `source_vintage`

## First-Slice Required Tables
- `ref.market_profiles`
- `ref.market_cbsa_membership`
- `ref.market_county_membership`
- `ref.county_dim`
- `ref.tract_dim`
- `ref.land_use_mapping`
- `foundation.cbsa_features`
- `foundation.tract_features`
- `foundation.market_tract_geometry`
- `foundation.market_county_geometry`
- `foundation.market_cbsa_geometry`
- `qa.foundation_validation_results`
- `qa.foundation_geography_coverage`
- `qa.foundation_null_rates`
- `qa.ref_validation_results`
- `qa.ref_geography_coverage`
- `qa.ref_unmapped_land_use_codes`
- `scoring.tract_scores`
- `scoring.cluster_seed_tracts`
- `zones.zone_input_candidates`
- `zones.contiguity_zone_components`
- `zones.contiguity_zone_summary`
- `zones.contiguity_zone_geometries`
- `zones.cluster_assignments`
- `zones.cluster_zone_summary`
- `zones.cluster_zone_geometries`
- `parcel.parcels_canonical`
- `parcel.parcel_join_qa`
- `parcel.parcel_lineage`
- `parcel.retail_parcels`
- `qa.parcel_validation_results`
- `qa.parcel_unmapped_use_codes`
- parcel geometry continues to be served from existing `.RDS` files in this slice

## Block-To-Tract Rule
We do not require a standalone `ref.block_tract_crosswalk` table in the first pass where block GEOIDs are already available in source systems.

- tract GEOID = first 11 characters of block GEOID
- block GEOID = 15 characters total

## Compatibility Rule
Prepared DuckDB products are additive in this slice. Existing section artifacts remain valid transition outputs until notebook modules are fully migrated to DuckDB reads.
