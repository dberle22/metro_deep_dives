# Retail Opportunity Finder Notebook Build

This area is the downstream notebook-serving layer for ROF V2.

## Role
- read prepared DuckDB products and lightweight section artifacts
- run section QA and visual assembly
- keep heavy analytics out of `.qmd` files

## Read-Only Rule
- notebook-build scripts must not publish or overwrite DuckDB tables
- upstream Layers 01-05 must already be built before notebook-build runs
- notebook-build scripts may emit compatibility artifacts under `sections/*/outputs/` for existing visuals and integration consumers

## Current Consumer Scripts
- `run_consumer_build.R`
- `sections/01_setup/section_01_build.R`
- `sections/01_setup/section_01_checks.R`
- `sections/01_setup/section_01_visuals.R`
- `sections/02_market_overview/section_02_build.R`
- `sections/02_market_overview/section_02_checks.R`
- `sections/02_market_overview/section_02_visuals.R`
- `sections/03_eligibility_scoring/section_03_build.R`
- `sections/03_eligibility_scoring/section_03_checks.R`
- `sections/03_eligibility_scoring/section_03_visuals.R`
- `sections/04_zones/section_04_build.R`
- `sections/04_zones/section_04_checks.R`
- `sections/04_zones/section_04_visuals.R`
- `sections/04_zones/section_04_cluster_build.R`
- `sections/04_zones/section_04_cluster_checks.R`
- `sections/04_zones/section_04_cluster_visuals.R`
- `sections/05_parcels/section_05_build.R`
- `sections/05_parcels/section_05_checks.R`
- `sections/05_parcels/section_05_visuals.R`
- `sections/06_conclusion_appendix/section_06_build.R`
- `sections/06_conclusion_appendix/section_06_visuals.R`
- `sections/06_conclusion_appendix/section_06_checks.R`

## Transition Rule
Existing `sections/` scripts remain active during migration. New notebook-build modules should prefer prepared products from `data_platform/` and only use legacy artifacts when no prepared source exists yet.
