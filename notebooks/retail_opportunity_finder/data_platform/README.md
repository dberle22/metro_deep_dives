# Retail Opportunity Finder Data Platform

This area is the upstream preparation layer for Retail Opportunity Finder V2.

## Goals
- Publish reusable ROF-ready analytical products into DuckDB.
- Move heavy scoring, contiguity, clustering, and parcel prep out of notebook sections.
- Preserve market-aware outputs so downstream notebook builds can stitch prepared products by market.

## Layer Layout
- `layers/00_reference_membership/`: shared reference dimensions and membership bridges.
- `layers/01_foundation_features/`: upstream tract and metro feature service contracts.
- `layers/02_tract_scoring/`: tract scoring workflow and serving products.
- `layers/03_zone_build/`: contiguity-zone and cluster-zone workflow and serving products.
- `layers/04_parcel_standardization/`: parcel canonicalization contracts and future workflow.
- `layers/05_market_serving_prep/`: parcel-zone serving prep contracts and future workflow.
- `shared/`: shared platform helpers and DuckDB bootstrap utilities.
- `contracts/`: schema, naming, and lineage contracts.

## Current Transition Mode
- Existing `sections/` scripts remain runnable.
- Section 03 and Section 04 can now use shared upstream workflow functions from this area.
- Parcel automation remains intentionally out of scope for this first slice.
