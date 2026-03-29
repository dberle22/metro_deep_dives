# Parcel Standardization

This folder now centers on one manual county ETL:

- `parcel_etl_manual_county_v2.R`

That script is the working parcel standardization path for Section 05.

## Current Workflow

The current workflow is intentionally manual and county-first:

1. set county config directly in `parcel_etl_manual_county_v2.R`
2. read and clean one county tabular file
3. write county tabular rows into `rof_parcel.parcel_tabular_clean`
4. read and trim one county geometry file
5. write one county geometry `.rds`
6. run an in-memory tabular-to-geometry join check
7. write county QA artifacts locally

This keeps the expensive spatial data out of DuckDB and stores county geometry
as lightweight R artifacts instead.

## Active Files

- `parcel_etl_manual_county_v2.R`
  Manual county ETL used for current parcel onboarding and reruns.

- `fl_county_run_checklist.md`
  Florida county completion checklist for the current manual workflow.

## Output Contract

DuckDB:

- `rof_parcel.parcel_tabular_clean`
  County-scoped tabular rows, replaced one county at a time by `county_tag`.

Geometry on disk:

- `/Users/danberle/Documents/projects/data/property_taxes/parcel_geom/<state>/<county_tag>_geom.rds`

QA on disk:

- `/Users/danberle/Documents/projects/data/property_taxes/parcel_geom/<state>/qa/<county_tag>_join_qa.rds`
- `/Users/danberle/Documents/projects/data/property_taxes/parcel_geom/<state>/qa/<county_tag>_join_qa_unmatched.csv`

## Notes

- Geometry duplicates are preserved in the current workflow.
- County geometry is stored for spatial analysis and plotting, not in DuckDB.
- If a county has problematic geometry, use `repair_invalid_geom <- TRUE` in
  `parcel_etl_manual_county_v2.R` only when needed.
