# Parcel Standardization Rebuild Plan

Status: completed and superseded by the working manual county ETL in
`sections/05_parcels/parcel_standardization/parcel_etl_manual_county_v2.R`.

## Purpose

This plan defines how to rebuild the parcel standardization workflow so that
county-by-county processing becomes the primary operating model.

The current geometry workflow is functional for batch-style processing but is
too difficult to debug when one county shapefile fails. The rebuild should favor
manual inspectability, county-level restartability, and downstream compatibility
with Section 05 and DuckDB publish.

## Goals

1. Make one-county processing the default geometry workflow.
2. Reduce unnecessary abstraction in the geometry build path.
3. Preserve the county output contract already used downstream.
4. Keep aggregate manifest refresh and DuckDB publish as separate follow-on
   steps rather than coupling them to the county build.
5. Support manual RStudio execution line by line.

## Non-Goals

1. Rebuild the parcel attribute standardization flow from scratch.
2. Redesign the Section 05 parcel model.
3. Change the DuckDB parcel schema contract more than necessary.
4. Solve every county-specific geometry issue in one pass.

## Final Working Pattern

```text
set one county in parcel_etl_manual_county_v2.R
  -> read and clean one county tabular file
  -> write county tabular rows to rof_parcel.parcel_tabular_clean
  -> read and trim one county geometry file
  -> write one county geometry .rds
  -> run in-memory join QA
  -> write county QA artifacts locally
```

## Final Files After Rebuild

Kept:

- `sections/05_parcels/parcel_standardization/parcel_etl_manual_county_v2.R`
- `sections/05_parcels/parcel_standardization/fl_county_run_checklist.md`
- `sections/05_parcels/parcel_standardization/README.md`

Removed during cleanup:

- the older batch parcel standardization scripts
- the earlier manual county ETL draft

## Rebuild Steps

### Implemented End State

What shipped:

- one manual county ETL script
- county tabular rows written into DuckDB
- county geometry stored as `.rds` under `property_taxes/parcel_geom/<state>/`
- county QA stored under `property_taxes/parcel_geom/<state>/qa/`
- duplicate parcel geometries preserved
- all targeted Florida counties processed

What changed from the original plan:

- no aggregate manifest rebuild script was kept
- no geometry publish to DuckDB was kept
- no statewide tabular pre-step was required in the final operating model

### Original Step 1: Lock the county-first contract

Define the new primary geometry workflow inputs and outputs.

Inputs:

- one county tabular source file
- one county shapefile path
- output root

Outputs:

- `county_outputs/<county_tag>/parcel_geometries_raw.rds`
- `county_outputs/<county_tag>/parcel_geometries_analysis.rds`
- `county_outputs/<county_tag>/parcel_geometry_join_qa.rds`

Dependencies:

- existing county output naming contract

Acceptance criteria:

- one-county run contract is documented and agreed
- downstream file names remain unchanged

### Original Step 2: Simplify runtime configuration

Refactor the geometry runtime so the primary county script takes one county
input directly rather than discovering all shapefiles first.

Define:

- `PARCEL_COUNTY_SHP` as the preferred county shapefile input
- optional `PARCEL_COUNTY_TAG` override

Keep current shared config support for:

- `PROPERTY_TAX_ROOT`
- `PROPERTY_STATE`
- `PROPERTY_DATA_ROOT`
- `PROPERTY_METADATA_ROOT`
- `PROPERTY_SHAPE_ROOT`
- `PARCEL_STANDARDIZED_ROOT`
- `PARCEL_DUCKDB_PATH`

Dependencies:

- direct county config in the working script

Acceptance criteria:

- county script can be run from one explicit shapefile path
- no batch file discovery is required for the primary workflow

### Original Step 3: Build a new county-only geometry script

Create a new primary county build path.

What it should contain:

- setup and path validation
- read standardized attributes
- read one county shapefile
- derive `join_key`
- derive `county_tag`
- join raw geometry to standardized attributes
- build analysis geometry
- compute county QA summary
- write county outputs

What it should avoid:

- statewide file discovery
- shapefile loops
- shapefile manifest construction during the main county build
- unnecessary helper layers where inline code is clearer

Dependencies:

- direct county config
- county tabular source file
- county shapefile

Acceptance criteria:

- county script runs line by line in RStudio
- county outputs are written in the same file locations currently used
- failure messages name the county and stage clearly

### Original Step 4: Isolate geometry failure stages

Make the county script explicit about where geometry can fail.

Break the script into visible stages:

1. read shapefile
2. transform CRS if needed
3. derive join key
4. join standardized attributes
5. build analysis geometry
6. write outputs

Dependencies:

- Step 3

Acceptance criteria:

- a malformed county can be identified by stage, not just by a generic script failure
- manual debugging no longer requires stepping through a statewide loop

### Original Step 5: Preserve the downstream county output contract

Ensure the new county-first script writes a stable county output contract.

Required final outputs:

- `<county_tag>_geom.rds`
- `<county_tag>_join_qa.rds`
- `<county_tag>_join_qa_unmatched.csv`

Dependencies:

- Step 3
- Section 05 assumptions
- DuckDB publish assumptions

Acceptance criteria:

- Section 05 continues to work from county outputs without major change
- publish script can continue to consume county analysis outputs

### Original Step 6: Move aggregate artifact refresh into a separate script

Create `02b_refresh_parcel_manifests.R` to scan completed county outputs and
rebuild aggregate artifacts.

This script should:

- read county QA outputs
- rebuild `parcel_geometry_join_qa_county_summary.rds`
- rebuild `parcel_geometry_file_manifest.{rds,csv}`
- rebuild `parcel_ingest_manifest.{rds,csv}`
- optionally rebuild `parcel_geometries_standardized_analysis.rds`

Dependencies:

- Step 3 producing one or more county outputs

Acceptance criteria:

- aggregate artifacts can be rebuilt deterministically from county outputs alone
- county processing remains independent from statewide aggregation

### Original Step 7: Adapt DuckDB publish to the county-first workflow

Final decision:

- keep only `rof_parcel.parcel_tabular_clean` in DuckDB
- keep geometry out of DuckDB
- store county geometry as `.rds` on disk

### Original Step 8: Rewrite operator-facing documentation

Update the README so it documents:

- the county-first workflow
- script purposes
- recommended RStudio run order
- environment variables
- target architecture

Dependencies:

- Steps 1-7 stable enough to document accurately

Acceptance criteria:

- README becomes the operational guide
- rebuild plan remains separate and implementation-oriented

### Original Step 9: Validate in increments

Validation sequence:

1. run the manual county ETL on one known-good county
2. inspect county outputs
3. run the same ETL on a problematic county like Alachua
4. run Section 05 from completed county outputs
5. confirm county tabular rows land in DuckDB

Dependencies:

- Steps 3-7

Acceptance criteria:

- at least one county succeeds end to end
- failures on problematic counties are isolated and inspectable
- county geometry and QA artifacts remain usable by Section 05

## Dependencies Summary

- each county run needs one tabular source file and one county shapefile
- Section 05 depends on county geometry `.rds` outputs
- DuckDB keeps only county-scoped tabular rows

## Risks

### Risk 1: Geometry issues remain county-specific

Even after simplification, some shapefiles may still fail because of malformed
geometry.

Mitigation:

- county-first workflow
- explicit per-stage failures
- inspect county outputs before moving on

### Risk 2: Output contract drift

If the manual county script changes filenames or folder structure, downstream
consumers may break.

Mitigation:

- preserve county geometry and QA filenames and folder layout exactly

### Risk 3: Logic drift inside one manual script

If too much county-specific logic accumulates in the manual ETL, maintenance
gets harder.

Mitigation:

- keep the county ETL explicit and compact
- avoid rebuilding broad helper frameworks

## Closeout

This plan is now a historical record of the rebuild. The working operational
entrypoint is:

- `sections/05_parcels/parcel_standardization/parcel_etl_manual_county_v2.R`
