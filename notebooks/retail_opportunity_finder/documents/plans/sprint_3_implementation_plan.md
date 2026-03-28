# Retail Opportunity Finder V2 - Sprint 3 Implementation Plan

## Purpose
Sprint 3 turns the new market configuration layer into an operational multi-market execution path for Florida while establishing the first durable foundation for parcel data infrastructure.

This plan is intentionally implementation-oriented. It defines what to build, in what order, which decisions to lock early, and what must be validated before Sprint 3 is considered complete.

## Sprint 3 Outcomes

By the end of Sprint 3, the project should support:

1. Running multiple Florida markets from one command.
2. Saving artifacts to market-specific locations instead of overwriting shared outputs.
3. Supporting side-by-side review of Jacksonville, Orlando, and Gainesville outputs without retaining a full historical archive of every run.
4. Removing the current Florida-only tract geometry assumption behind a small adapter layer.
5. Producing a parcel ETL/database design baseline so county CSV and SHP assets can be ingested into a structured platform before broader parcel expansion.

## Current Constraints To Design Around

### 1) Output overwrite risk
- Current section scripts write to fixed paths under `sections/*/outputs/`.
- Running a second market replaces the first market's artifacts.
- This blocks reproducible side-by-side QA and makes orchestrated multi-market runs unsafe.

### 2) Geometry portability gap
- Current tract geometry queries still reference `metro_deep_dive.geo.tracts_fl`.
- Florida alternate markets work.
- Non-Florida markets fail when tract geometry is required.

### 3) Parcel input fragmentation
- Parcel data currently exists as county-level CSV and SHP assets outside a stable canonical database layer.
- Section 05 still assumes a Florida-oriented standardized parcel output path.
- Without a structured landing model, later GA/SC/NC onboarding will create avoidable rework.

## Sprint 3 Workstreams

### Workstream A - Market-Partitioned Output Layout

#### Goal
Introduce a market-aware output system so artifacts are preserved per market without retaining a full copy of every run.

#### Locked decisions
- Keep current artifact filenames for compatibility, but write them inside market-specific directories.
- Default behavior: rerunning a market overwrites that market's current artifacts only.
- Do not store full historical artifact sets per run in-repo by default.
- For batch execution, write a lightweight comparison manifest that summarizes what ran and where outputs were written.

#### Proposed directory pattern

```text
notebooks/retail_opportunity_finder/sections/
  01_setup/
    outputs/
      jacksonville_fl/
      orlando_fl/
      gainesville_fl/
  02_market_overview/
    outputs/
      jacksonville_fl/
      orlando_fl/
      gainesville_fl/
  ...

notebooks/retail_opportunity_finder/integration/outputs/
  market_batch_manifest.csv
  market_batch_manifest.json
```

#### Design rules
- Section scripts should not hardcode `sections/.../outputs/...` as the only write destination.
- Shared helpers should expose:
  - `get_market_context()`
  - `resolve_output_path(section_id, artifact_name, ext = "rds")`
  - `resolve_market_output_dir(section_id)`
- Validation reports should include resolved output directory metadata.
- The integrated notebook should continue to work for single-market local development, but artifacts should be market-partitioned by default.
- Batch metadata should be small and comparison-oriented, not a substitute for the actual market outputs.

#### Implementation steps
1. Add shared market output context helpers in `sections/_shared/`.
2. Add output path resolver helpers keyed by `market_key`.
3. Refactor Section 01-03 writes to use market-specific output paths.
4. Refactor Section 01-03 readers/checks to use market-specific paths consistently.
5. Decide whether to maintain compatibility copies in legacy `outputs/` folders during transition.

#### Acceptance checks
- Jacksonville and Gainesville runs do not overwrite each other.
- Both markets produce complete Section 01-03 artifacts under separate market directories.
- Rerunning Gainesville overwrites Gainesville only and leaves Jacksonville unchanged.

### Workstream B - Batch Orchestration

#### Goal
Run multiple Florida markets from one command with deterministic logging and lightweight cross-market status tracking.

#### Locked decisions
- Start with a simple R orchestrator, not a workflow engine.
- Orchestrator should support an explicit market list argument.
- Execution order remains section-ordered within each market:
  `01 -> 02 -> 03` for Sprint 3 baseline.
- Start with sequential execution for correctness.
- Parallel execution can be deferred until output paths and logs are stable.
- Batch execution should produce one small comparison manifest, not a full artifact archive.

#### Proposed entrypoint

```text
notebooks/retail_opportunity_finder/scripts/run_markets.R
```

#### Required capabilities
- Accept:
  - market keys
  - optional section cap (`through_section`)
- For each market:
  - set market env
  - initialize market context
  - run build/check scripts in order
  - capture pass/fail, runtime, and artifact directory
- Write a consolidated batch manifest at the end

#### Implementation steps
1. Create orchestrator skeleton.
2. Add wrapper to execute section scripts with env vars.
3. Capture runtime and exit status by section and market.
4. Save batch manifest in machine-readable and analyst-readable forms.

#### Acceptance checks
- One command can run Jacksonville + Orlando + Gainesville.
- Failures are isolated by market and section.
- Batch manifest reports exact artifact locations and key QA summary fields.

### Workstream C - Geometry Source Adapter

#### Goal
Remove direct section dependency on `geo.tracts_fl` so the geometry source is isolated behind one shared adapter.

#### Locked decisions
- Keep geometry source resolution centralized in shared helpers/config.
- Preserve state-specific tract tables in DuckDB while allowing shared SQL to read from a combined supported-states tract geometry table where that reduces downstream Florida-only assumptions.
- Limit Sprint 3 geometry expansion to tract support for `FL`, `GA`, `SC`, and `NC`.
- Preserve explicit adapter failure behavior for unsupported states outside the current supported set.

#### Implemented shared interface
- `get_market_state_scope()`
- `resolve_tract_geometry_table(profile)`
- `build_tract_geometry_query(profile, cbsa_code)`
- `build_cbsa_geometry_query(profile, cbsa_code)`
- `build_county_geometry_query(profile, cbsa_code)`
- `query_tract_geometry_wkb(con, profile, cbsa_code)`
- `sf_from_wkb_df(df, data_cols, geometry_col = "geom_wkb")`

#### Implemented behavior
- Florida markets map to `metro_deep_dive.geo.tracts_fl`.
- Georgia markets map to `metro_deep_dive.geo.tracts_ga`.
- South Carolina markets map to `metro_deep_dive.geo.tracts_sc`.
- North Carolina markets map to `metro_deep_dive.geo.tracts_nc`.
- Shared tract SQL now reads from `metro_deep_dive.geo.tracts_supported_states` where a combined geometry source is sufficient.
- Unsupported states still raise a clear "unsupported geometry source" error.
- Section 01-03 no longer reference geometry tables inline.

#### Completed work
1. Moved geometry table selection and geometry query builders into `sections/_shared/config.R` and `sections/_shared/helpers.R`.
2. Refactored Section 01-03 geometry reads to use shared helpers rather than inline `tracts_fl` references.
3. Added shared WKB-to-`sf` conversion so geometry loading is consistent across Section 01-03.
4. Extended `scripts/etl/staging/get_tiger_geos.R` to ingest tract geometry for `FL`, `GA`, `SC`, and `NC`.
5. Wrote new DuckDB geometry tables: `metro_deep_dive.geo.tracts_fl`, `metro_deep_dive.geo.tracts_ga`, `metro_deep_dive.geo.tracts_sc`, `metro_deep_dive.geo.tracts_nc`, and `metro_deep_dive.geo.tracts_supported_states`.
6. Updated remaining tract feature SQL to stop assuming Florida-only tract geometry storage.
7. Added focused tests covering supported state resolution and explicit failure for unsupported states.

#### Validation completed
- No Section 01-03 script references `tracts_fl` directly.
- Jacksonville passed Section 01-03 build/check smoke validation after the adapter refactor.
- Wilmington, NC passed Section 01-03 build/check after GA/SC/NC tract geometry was loaded into DuckDB.
- `test_market_profile_config.R` passed with Florida resolution checks, GA/SC/NC resolution checks, and an explicit unsupported-state failure check.
- TIGER tract ingest completed successfully with these counts: FL `5,122`, GA `2,791`, SC `1,317`, NC `2,660`, combined supported states `11,890`.

#### Outcome
- Workstream C is complete.
- Geometry support is now in place for the current Southeast market set used by Sprint 3 and the near-term market profile registry.
- Remaining unsupported states are intentionally outside Sprint 3 scope and should continue to fail explicitly until new geometry tables are added.

### Workstream D - Parcel ETL and Database Foundation

#### Goal
Define and begin implementing the structured parcel landing layer for county CSV and SHP assets.

#### Locked decisions
- Sprint 3 should deliver the design baseline and ingestion contract, not full GA/SC/NC production ingestion.
- Use DuckDB as the first structured parcel store unless a stronger operational need emerges immediately.
- Treat raw county files as immutable landing inputs.
- Separate raw, standardized, and publish-ready parcel layers.

#### Recommended storage model

```text
raw parcel assets
  -> parcel ETL landing tables
  -> normalized parcel canonical tables
  -> ROF-ready publish views/artifacts
```

#### Proposed parcel layers

```text
parcel_raw_files
  metadata about source files, counties, vintages, load timestamps

parcel_raw_attributes
  minimally typed tabular ingest from county CSVs

parcel_raw_geometry
  geometry ingest from county SHPs / geopackages

parcel_standardized
  county-normalized canonical parcel schema

parcel_publish
  ROF-facing tables/views optimized for Section 05 consumption
```

#### Canonical parcel dimensions to define now
- `state`
- `county_fips`
- `source_county_name`
- `parcel_id_raw`
- `parcel_id_canonical`
- `land_use_code_raw`
- `land_use_code_std`
- `site_address`
- `owner_name`
- `assessed_value_total`
- `assessed_value_land`
- `building_area_sqft`
- `land_area_sqft`
- `last_sale_date`
- `last_sale_price`
- `geometry`
- `source_system`
- `source_file`
- `ingest_run_id`
- `transform_version`

#### Sprint 3 parcel ETL deliverables
- Parcel ETL architecture note
- Recommended DuckDB schema layout
- County ingest manifest format
- One pilot ingest path for a Florida county pair if time allows
- Clear handoff into Sprint 5 implementation

#### Acceptance checks
- We have a written and agreed parcel database design.
- We know where raw county files live and how they map to ingest manifests.
- We have a canonical parcel contract draft suitable for Sprint 5 implementation.

## Sequencing Plan

### Phase 1 - Foundations
1. Implement shared market output context.
2. Implement market-aware output path resolver.
3. Implement geometry adapter shell.

### Phase 2 - Section Refactor
1. Refactor Section 01 to resolved outputs and shared geometry adapter.
2. Refactor Section 02 to resolved outputs and shared geometry adapter.
3. Refactor Section 03 to resolved outputs and shared geometry adapter.

### Phase 3 - Batch Run Pilot
1. Implement orchestrator.
2. Run Jacksonville + Orlando.
3. Extend to Gainesville after first two-market success.
4. Write a compact batch comparison manifest for QA review.

### Phase 4 - Parcel Platform Baseline
1. Inventory parcel file holdings.
2. Draft parcel ETL/database design note.
3. Define canonical parcel ingest manifest and schema proposal.

## Concrete Deliverables

### Code
- Shared market output context module
- Shared output path resolver
- Shared geometry adapter
- Multi-market orchestrator script
- Refactored Section 01-03 scripts using run-aware outputs

### Documentation
- Sprint 3 batch manifest spec
- Parcel ETL/database foundation note
- Updated output contracts for market/run partitioning

### Validation
- Jacksonville smoke run
- Orlando smoke run
- Gainesville smoke run
- Two-market and three-market Florida manifest output

## Open Design Questions To Resolve Early

1. Should compatibility files remain in section `outputs/` during the transition, or should Sprint 3 fully move consumers onto market-partitioned paths?
2. Should batch manifests be JSON, CSV, or both? Recommendation: both.
3. Should parcel ETL code live under `sections/05_parcels/parcel_standardization/` or move to a higher-level shared data platform directory? Recommendation: keep current code where it is for Sprint 3, but design for later extraction.
4. Should county parcel raw files be registered through a manifest file or directory convention? Recommendation: manifest file.

## Risks

### Risk 1 - Compatibility churn
Changing output locations can break downstream sections and the integration notebook if done all at once.

Mitigation:
- introduce shared readers/writers first
- keep compatibility aliases temporarily

### Risk 2 - Geometry support confusion
Adding non-Florida market profiles before multi-state geometry exists can create false expectations.

Mitigation:
- adapter must fail explicitly for unsupported states
- document Florida-only runtime support in Sprint 3 checkpoint

### Risk 3 - Parcel platform scope creep
Parcel ETL can easily absorb the whole sprint if treated as full production ingestion.

Mitigation:
- limit Sprint 3 parcel work to architecture, schema, manifest, and optional pilot ingest only

## Definition of Done

Sprint 3 is done when:

1. A single command can run at least two Florida markets end to end through Section 03.
2. Output artifacts are preserved independently by market.
3. A consolidated batch manifest exists with runtime, pass/fail, key QA summaries, and artifact paths.
4. Geometry source selection is centralized and Florida no longer relies on inline `tracts_fl` references in section scripts.
5. A parcel ETL/database foundation document and canonical ingest proposal are complete.
