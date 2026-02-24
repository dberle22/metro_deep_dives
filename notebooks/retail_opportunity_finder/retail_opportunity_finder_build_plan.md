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
- [ ] Build and test contiguity + dissolve workflow
- [ ] Produce zone summaries and maps
- [ ] Persist `zones` artifacts for parcel overlay module

**Deliverable:** Section 4 outputs validated and reusable.

## Sprint D: Section 5 module (parcels + shortlist)
- [ ] Build and test retail intensity + overlay logic
- [ ] Build shortlist table and maps
- [ ] Persist parcel shortlist artifacts

**Deliverable:** Section 5 outputs validated and reusable.

## Sprint E: Section 6 module + `.qmd` integration
- [ ] Finalize conclusion/appendix module content
- [ ] Integrate selected outputs from Section modules into `.qmd`
- [ ] Run full render and resolve integration issues
- [ ] Final formatting consistency pass (labels, units, captions, source notes)

**Deliverable:** complete V1 notebook from funnel to shortlist using modular section pipeline.

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
