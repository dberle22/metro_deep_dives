# Retail Opportunity Finder Notebook Build Plan

## 1) Analysis of the current notebook state

### What exists now
- `notebooks/retail_opportunity_finder/retail_opportunity_finder_notebook_flow.md` defines a full V1 vision from setup through parcel shortlist.
- `notebooks/retail_opportunity_finder/retail_opportunity_finder_dash_v1.qmd` is partially implemented and currently covers:
  - Setup, DB connection, geometry loading, quick QA
  - Section 2.1 KPI tiles
  - Section 2.1 peer ranking table
  - Section 2.1 benchmark table
  - Section 2.2 population trend + all-metro distribution boxplots
- The `.qmd` currently stops at `## Section 3: Eligibility & Scoring Model` and only includes the `### 3.1 KPI dictionary` heading.
- Section 2 has now been refactored into modular scripts and validated via:
  - `notebooks/retail_opportunity_finder/sections/02_market_overview/section_02_build.R`
  - `notebooks/retail_opportunity_finder/sections/02_market_overview/section_02_visuals.R`
  - `notebooks/retail_opportunity_finder/sections/02_market_overview/section_02_checks.R`

### Key gap summary
- The flow document defines Sections 3, 4, 5, and 6 in detail, but they are not yet implemented in the `.qmd`.
- Critical outputs still missing:
  - Funnel/gates diagnostics and eligibility map
  - Tract score computation + diagnostics + top tract table with “why tags”
  - Contiguous zone creation and zone summary outputs
  - Parcel/retail overlay and parcel shortlist
  - Final conclusion and appendix sections

### Data/model dependencies already implied
- Tract-level model table (`tract_features`) with core KPIs and eligibility fields
- Metro-level feature table (`cbsa_features`) already used in Section 2
- Geometries for tracts/counties/CBSA and parcel polygons
- QA checks in `notebooks/retail_opportunity_finder/tract_features_qa.sql`

### Risks to manage early
- Metric scale consistency (percent vs fraction) and sign direction for scoring
- Geometry validity and CRS consistency before adjacency/zone dissolve
- Missingness in rent/home value/commute/BPS fields may materially change gate counts
- County-to-tract BPS assignment assumptions need explicit caveats in appendix

## 2) Build sequence (recommended implementation order)

### Phase 0: Organize repo for modular section development
1. Create a section-first structure so each notebook section is built and tested independently before `.qmd` integration.
2. Recommended layout:
  - `notebooks/retail_opportunity_finder/sections/01_setup/`
  - `notebooks/retail_opportunity_finder/sections/02_market_overview/`
  - `notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/`
  - `notebooks/retail_opportunity_finder/sections/04_zones/`
  - `notebooks/retail_opportunity_finder/sections/05_parcels/`
  - `notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/`
3. Inside each section folder, add:
  - `section_XX_build.R` (data prep + transforms)
  - `section_XX_visuals.R` (plots/tables only)
  - `section_XX_checks.R` (sanity checks/QA assertions)
  - optional `outputs/` for intermediate artifacts (RDS/CSV/figures)
4. Add shared utilities:
  - `notebooks/retail_opportunity_finder/sections/_shared/helpers.R`
  - `notebooks/retail_opportunity_finder/sections/_shared/config.R`
5. Define a simple integration rule: only validated section outputs get pulled into `retail_opportunity_finder_dash_v1.qmd`.

### Phase 1: Stabilize shared inputs and conventions
1. Lock KPI definitions in one place (`_shared` docs/comments + dictionary object).
2. Confirm required fields in `tract_features` and geometry tables.
3. Add reusable run metadata utility (run date, data vintages, optional git hash).
4. Standardize naming contracts for section outputs (object names, file names, column schema).
5. Use `scripts/utils.R` as shared runtime bootstrap for all section scripts.
6. Map and document reused functions from `R/` (e.g., growth, benchmarking, ACS helpers) for section ownership.

### Phase 2: Build Section 3 module (Eligibility & Scoring)
1. Implement KPI dictionary table (compact, reader-facing).
2. Build gate walkthrough:
  - Funnel counts table by gate step
  - Price proxy histogram + 70th percentile line
  - Growth histogram + median marker
  - Eligible tracts binary map
3. Implement tract ranking model:
  - Compute z-scores within metro
  - Apply locked weights
  - Persist component contributions
4. Add score diagnostics:
  - Score histogram
  - Growth vs density scatter with top tracts highlighted
  - Optional component correlation heatmap
5. Produce top-tract outputs:
  - Top N score plot
  - Top 25 table with why-tags and component contributions
6. Add sensitivity mini-check (optional hidden chunk): top-20 overlap under alternative weights.
7. Save section outputs for integration (tables/plots + `scored_tracts` artifact).

### Phase 3: Build Section 4 module (Zone creation)
1. Select top-N tracts (default 50) from scoring output.
2. Compute contiguity (touching tracts) and connected components.
3. Dissolve components into zone polygons and generate stable zone labels.
4. Build zone summary table (tract count, pop, growth, density, units per 1k, price proxy).
5. Add zone map with labels + short narrative bullets.
6. Save section outputs for integration (`zones`, `zone_summary`, map objects/files).

### Phase 4: Build Section 5 module (Retail overlay + parcel shortlist)
1. Derive tract-level retail intensity from parcels (count + area density).
2. Build corridor context maps:
  - Retail parcel count choropleth
  - Retail area density choropleth
  - Zone + retail overlay
3. Filter parcels to target zones and create shortlist scoring logic.
4. Publish shortlist map + top parcel table (25–50 rows).
5. Optional micro deep-dive for 1–2 zones.
6. Save section outputs for integration (`parcel_shortlist`, overlay maps, deep-dive assets).

### Phase 5: Build Section 6 module (Conclusion + appendix)
1. Add conclusion bullets (top zones, why, next actions).
2. Add appendix:
  - KPI definitions
  - Assumptions and caveats
  - QA summary and validation checks

### Phase 6: Integrate modules into `.qmd`
1. Import only final artifacts from section modules into `retail_opportunity_finder_dash_v1.qmd`.
2. Keep heavy transforms in section scripts; keep `.qmd` focused on narrative + final outputs.
3. Run full render test after each integration pass.

## 3) Action plan (execution checklist)

## Sprint 0: Repo organization and scaffolding
- [x] Create `sections/` folder structure for Sections 01–06 + `_shared`
- [x] Add `build/visuals/checks` script skeletons per section
- [x] Add shared `config.R` and `helpers.R`
- [x] Define output contracts (file/object naming + expected schemas)

**Deliverable:** Modular repo layout ready for independent section development/testing.

## Sprint A: Shared foundations
- [x] Lock KPI dictionary and thresholds in shared config
- [x] Validate required input fields and geometry assumptions
- [x] Add reusable metadata and QA helper routines
- [x] Wire all section scripts to shared bootstrap that sources `scripts/utils.R`
- [x] Create a short function reuse matrix (Section -> `R/` functions used)

**Deliverable:** Stable shared layer used by all section modules.

## Section 2 refactor checkpoint (completed before Sprint B)
- [x] Ported Section 2 transformations out of `.qmd` into Section 02 module scripts
- [x] Implemented Section 02 build artifacts:
  - `section_02_kpi_tiles.rds`
  - `section_02_peer_table.rds`
  - `section_02_benchmark_table.rds`
  - `section_02_pop_trend_indexed.rds`
  - `section_02_distribution_long.rds`
- [x] Implemented Section 02 visual outputs:
  - `section_02_visual_objects.rds`
  - `section_02_pop_trend_plot.png`
  - `section_02_distribution_plot.png`
- [x] Implemented and passed Section 02 validation checks:
  - `section_02_validation_report.rds`
  - `schema_pass=TRUE`, `logic_pass=TRUE`
- [x] Updated output contracts to include new Section 02 artifacts

**Deliverable:** Section 02 is now independently buildable/testable and ready for `.qmd` integration.

## Sprint B: Section 3 module (eligibility + scoring)
- [x] Build and test Section 3 scripts (`build`, `visuals`, `checks`)
- [x] Validate gate counts and score distribution against QA SQL
- [x] Persist scored tract outputs for downstream zone work

**Deliverable:** Section 3 outputs validated and versioned for reuse.

## Section 3 checkpoint (completed)
- [x] Implemented Section 03 build artifacts:
  - `section_03_funnel_counts.rds`
  - `section_03_eligible_tracts.rds`
  - `section_03_scored_tracts.rds`
  - `section_03_top_tracts.rds`
  - `section_03_tract_component_scores.rds`
  - `section_03_tract_component_scores.csv`
- [x] Added tract-level component/score table output covering all tracts (scored + unscored with flags)
- [x] Implemented Section 03 visual outputs and map/diagnostic plots
- [x] Implemented and passed Section 03 validation checks:
  - `section_03_validation_report.rds`
  - `schema_pass=TRUE`, `logic_pass=TRUE`

**Deliverable:** Section 03 module is independently buildable/testable with complete tract-level scoring outputs.

## Sprint C: Section 4 module (zones)
- [x] Build and test contiguity + dissolve workflow
- [x] Produce zone summaries and maps
- [x] Persist `zones` artifacts for parcel overlay module

**Deliverable:** Section 4 outputs validated and reusable.

## Section 4 checkpoint (completed)
- [x] Implemented Section 04 build steps 1-5:
  - input readiness checks
  - eligible tract candidate universe
  - adjacency + connected components
  - dissolved zone geometries + deterministic labels
  - zone summary metrics
- [x] Implemented Section 04 visuals:
  - zone map (`section_04_zone_map.png`)
  - render-ready visual objects (`section_04_visual_objects.rds`)
- [x] Implemented and passed Section 04 validation checks:
  - `section_04_validation_report.rds`
  - hard checks pass (`pass=TRUE`)
  - warning captured: zone count `16` outside target band `[3, 8]`

**Deliverable:** Section 04 module is independently buildable/testable and ready for Sprint D dependencies.

## Sprint D: Section 5 module (parcels + shortlist)
- [x] Build and test retail intensity + overlay logic
- [x] Build shortlist table and maps
- [x] Persist parcel shortlist artifacts

**Deliverable:** Section 5 outputs validated and reusable.

## Section 5 checkpoint (completed)
- [x] Implemented Section 05 build steps D1-D3:
  - input readiness + canonicalization
  - retail classification + tract retail intensity
  - dual-system zone overlays + parcel shortlist scoring
- [x] Implemented Section 05 visual outputs (D4):
  - zone overlay maps (contiguity + cluster)
  - shortlist maps (contiguity + cluster)
  - top parcel tables + system comparison objects
- [x] Implemented and passed Section 05 validation checks (D5):
  - `section_05_validation_report.rds`
  - hard checks pass (`pass=TRUE`)
  - warnings captured for follow-up (zone assignment rate warning band + invalid shortlist geometries)
- [x] Added shared agent workflow reference:
  - `notebooks/retail_opportunity_finder/sections/_shared/AGENT_INSTRUCTIONS.md`

**Deliverable:** Section 05 module is independently buildable/testable and integration-ready.

## Sprint E: Section 6 module (conclusion + appendix)
- Overview doc: `notebooks/retail_opportunity_finder/sections/06_conclusion_appendix/sprint_overview.md`
- [x] Finalize conclusion/appendix module content
- [x] Build Section 06 artifacts (`build`, `visuals`, `checks`)
- [x] Validate appendix assumptions/QA references against Sections 03-05 outputs

**Deliverable:** Section 06 module is independently buildable/testable and ready for integration.

## Section 6 checkpoint (completed)
- [x] Implemented Section 06 build artifacts:
  - `section_06_conclusion_payload.rds`
  - `section_06_appendix_payload.rds`
- [x] Implemented Section 06 visual outputs:
  - `section_06_visual_objects.rds`
  - conclusion summary + shortlist summary + QA/assumptions tables
- [x] Implemented and passed Section 06 validation checks:
  - `section_06_validation_report.rds`
  - hard checks pass (`pass=TRUE`)

**Deliverable:** Section 06 outputs are finalized and Sprint F integration-ready.

## Sprint F: Notebook integration + render hardening
- Overview doc: `notebooks/retail_opportunity_finder/sprint_f_integration_overview.md`
- [ ] Integrate selected outputs from Sections 03-06 into `.qmd`
- [ ] Run full render and resolve integration/runtime issues
- [ ] Final formatting consistency pass (labels, units, captions, source notes)
- [ ] Publish integration validation log

**Deliverable:** complete V1 notebook from funnel to shortlist using modular section pipeline.

## Sprint F proposal (integration sprint)

### Goal
Complete notebook integration as a dedicated sprint with render stability and presentation quality as the primary acceptance criteria.

### Scope
1. Integrate validated artifacts from Sections 03-06 into `retail_opportunity_finder_dash_v1.qmd`.
2. Keep heavy computation in section scripts and keep `.qmd` as reporting layer.
3. Run full render/fix loop until notebook completes end-to-end without manual intervention.

### Execution plan
1. Preflight and contracts
- [ ] Confirm all required artifacts exist from Sections 03-05.
- [ ] Confirm schema compatibility for `.qmd` consumption objects.
- [ ] Lock plot/table object names referenced by `.qmd`.
2. Section 03 integration pass
- [ ] Wire funnel, diagnostics, and top tract outputs from Section 03 artifacts.
- [ ] Validate figure/table rendering and narrative references.
3. Section 04 integration pass
- [ ] Wire zone map + summary outputs from Section 04 artifacts.
- [ ] Ensure label/units consistency with Section 03.
4. Section 05 integration pass
- [ ] Wire cluster-default parcel overlay and shortlist outputs.
- [ ] Add compact contiguity-vs-cluster comparison display.
5. Section 06 integration pass
- [ ] Wire conclusion and appendix artifacts from Section 06 outputs.
- [ ] Validate appendix references and caveat consistency.
6. Full render and polish
- [ ] Run full notebook render.
- [ ] Resolve all integration/runtime errors.
- [ ] Run final formatting consistency pass across titles, captions, units, and source notes.

### Acceptance gates
- [ ] Full `.qmd` render completes without manual edits or reruns.
- [ ] All required visuals/tables appear with correct labels and ordering.
- [ ] Cluster system is default in Section 05 narrative; contiguity remains available in comparison outputs.
- [ ] Appendix includes explicit assumptions and QA caveats from Sections 03-05.
- [ ] Integration validation log is saved (render status + known warnings).

## 4) Recommended implementation notes
- Reuse `scripts/utils.R` for package loading and shared function sourcing so section modules match existing project runtime.
- Keep section-specific helpers additive; avoid duplicating functions that already exist in `R/`.
- Keep all thresholds/weights as top-level parameters for easier tuning.
- Materialize intermediate tables/data frames (`eligible_tracts`, `scored_tracts`, `zones`, `parcel_shortlist`) per section module to simplify debugging.
- Add explicit NA handling rules in each metric transformation chunk.
- For map sections, enforce a single projected CRS for area/distance calculations; transform only for display as needed.
- Keep optional analyses (`sensitivity`, `micro deep dive`) behind `eval: false` or parameterized toggles until core path is stable.
- Treat `.qmd` as an integration/reporting layer, not the primary computation layer.

## 5) Definition of done
- The `.qmd` renders from start to finish without manual intervention.
- Every section in `retail_opportunity_finder_notebook_flow.md` is either implemented or explicitly marked optional with rationale.
- Core artifacts exist in the rendered output:
  - Metro context visuals
  - Eligibility funnel + diagnostics
  - Ranked tract table with explanations
  - Zone map + zone summary
  - Parcel shortlist map + table
  - Conclusion + appendix with assumptions/QA

## 6) Future improvements backlog

### Section 05 geometry quality hardening
- Add optional geometry repair mode (`st_make_valid`) before shortlist publish.
- Add post-repair invalid geometry audit with county-level diagnostics.
- Decide whether invalid shortlist geometries should become hard-fail in validation.

### Section 05 assignment coverage improvements
- Evaluate boundary sensitivity mode (buffer-based parcel-to-zone assignment).
- Compare strict in-zone vs buffered assignment impact on shortlist stability.
- Tune warning/error thresholds for zone assignment rates with baseline evidence.

### Scoring and model calibration
- Add sensitivity analysis for Section 05 score weights and rank overlap.
- Benchmark alternative local retail context features (nearest-neighbor density, distance-weighted intensity).
- Add calibration notebook chunk to compare shortlist outputs across weight sets.

### Integration and ops
- Add automated “build + checks + visuals + render” runner script for CI/local.
- Persist a consolidated run manifest with artifact checksums and validation statuses.
- Add lightweight regression checks to detect large output shifts between runs.

### UX/reporting improvements
- Add optional zone micro deep-dive pages in Section 05.
- Add county and zone drill-down tables with export-ready CSV companions.
- Add source/caveat footers directly under each major Section 05 visual.
