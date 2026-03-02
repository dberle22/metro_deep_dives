# Retail Opportunity Finder - MVP Improvement Sprint Plan

## Goal
Improve the MVP notebook for business clarity, model correctness, visual context, and shortlist trust before the next build cycle.

## Scope Summary
- Rewrite Sections 1-3 in plain language.
- Improve Section 2 benchmark/table polish and add a full-market geography stage map.
- Redesign Section 3 scoring/gating workflow to score all tracts first.
- Simplify Section 3 visuals and improve Top 25 table UX.
- Improve map context (roads/water/metro extent) in Sections 3-5.
- Clarify Section 4/5 business narrative and scoring interpretation.
- Fix assessed value handling in parcel shortlist scoring.

## Workstreams by Section

## 1) Section 1-3 Narrative Rewrite (Business-First)

### Objective
Convert technical language into plain-language explanation of goals, methods, assumptions, and decision implications.

### Changes
- Replace technical-first phrasing with `What we are doing`, `Why it matters`, `What this means`.
- Move formula-heavy details into appendix or collapsible technical notes.
- Keep method transparency but remove unnecessary jargon in main body.

### Dependencies
- Existing section artifacts only (no new upstream data).
- Finalized terminology for gates, scores, and zone systems.

### Upstream needs
- None.

## 2) Section 2 Market Snapshot Enhancements

### Objective
Improve readability and geographic context in metro overview.

### Changes
- Round benchmark `mean_travel_time` display values.
- Improve boxplot design: stronger Jacksonville highlight, cleaner facet labels/scales.
- Add full-market tract map to establish geographic stage before model sections.
- Add roads and waterways context layers from TIGER for market orientation maps.

### Dependencies
- Section 02 visual objects update (`section_02_visuals.R`) and/or integration override chunk.
- Tract geometry artifact for full-market map source.
- TIGER geometry ingestion workflow (reuse `scripts/etl/staging/get_tiger_geos.R` patterns).

### Upstream needs
- If full-market map includes additional context layers (roads/water), add static layer artifacts in advance.
- Add Section 02 upstream artifacts for context layers:
  - `section_02_market_roads_sf.rds`
  - `section_02_market_water_sf.rds`
- Persist these as static local artifacts to preserve artifact-only render policy.
- Future optimization note: reuse existing DuckDB geo layers for CBSA/counties/places and restrict TIGER ingestion to roads + waterways only to reduce runtime and ingestion overhead.

## 3) Section 3 Model Redesign (Score-First, Gate-Second)

### Status
- MVP complete: scoring now runs across all tracts and includes `median_hh_income`.
- Deferred to V2: score-aware post-gate threshold logic.
- Deferred to V2: configurable gate/weight toggles in a single runtime control block.
- Deferred long-term: sensitivity comparison outputs for income weight scenarios.

### Objective
Correct workflow so scoring applies to all tracts first, then gates enforce priority filtering.

### Changes
- Compute component scores and total tract score for all tracts.
- Redefine gates to align with top-performing tracts (score-aware thresholds).
- Add configurable gate thresholds and variable toggles.
- Add optional `median_income` into model component set.

### Dependencies
- Section 03 build/check updates.
- Shared config updates for dynamic gates/variable inclusion.
- Updated validation logic and expected funnel behavior.

### Upstream needs
- Add `median_income` (or chosen income proxy) into `tract_features.sql` and QA checks.
- Ensure column contract updates in `REQUIRED_COLUMNS` and output contracts.

## 4) Section 3 Visual + Table UX Simplification

### Status
- MVP complete in integration QMD.
- Replaced low-value Section 3 distribution diagnostics with a score-driver contribution view.
- Top 25 table now renders in a fixed-height scrollable container.

### Objective
Focus visuals on narrative value and improve usability of top-tract output.

### Changes
- Remove low-value distribution visuals (or demote to appendix).
- Keep core visuals: eligibility/score map, concise diagnostics, top tracts.
- Render Top 25 table in a fixed-height scrollable container.

### Dependencies
- Section 03 visual object update and/or integration rendering wrappers.
- HTML/CSS table container styling in QMD.

### Upstream needs
- None beyond Section 03 visuals refresh.

## 5) Spatial Context Upgrades (Sections 3-5)

### Objective
Provide better market context in maps (roads, waterways, metro extent cues).

### Changes
- Add contextual basemap-like layers to eligible tracts, zone maps, and shortlist maps.
- Ensure map extents show broader metro context before zooming into shortlisted zones.

### Dependencies
- Section 03/04/05 map visual updates.
- Consistent CRS and layer alignment policy.

### Upstream needs
- Prebuilt static context layers (roads/waterways/base polygons) saved as local artifacts to preserve artifact-only runtime.
- Do not rely on live tile APIs in notebook render.

## 6) Section 4 Zone Narrative Clarification

### Status
- MVP complete in integration QMD.
- Section 4 now uses a cluster-only narrative.
- Cluster build now runs from Section 3 top-scoring tract seed universe (top 25% by tract score).
- Cluster summaries now align to 3-year growth metrics.

### Objective
Explain cluster zone construction in plain language and make downstream parcel overlay decision-ready.

### Changes
- Add stepwise explanation of cluster construction from score-based tract seeds.
- Remove contiguity visuals/copy from Section 4 render flow.
- Tie cluster method choice to business use (operational submarket targeting).

### Dependencies
- Section 03 score outputs and cluster seed artifact.
- Section 04 cluster build/check/visual artifacts.
- Final language alignment with Section 5 shortlist narrative.

### Upstream needs
- None.

## 7) Section 5 Business Logic + Data Quality Fixes

### Status
- In progress.
- Next execution phase after Section 4 cluster narrative rebuild.

### Objective
Make parcel shortlist explainable, cluster-first, and robust to value-data edge cases.

### Changes
- Keep only the cluster zone approach in Section 5 outputs and QMD rendering.
- Add a market context parcel map first (residential + retail parcels) to establish natural corridor patterns.
- Add a second map with cluster zones over parcel context.
- Replace raw `assessed_value` dependence in parcel scoring with value-density logic:
  - Compute `assessed_value_psf = assessed_value / parcel_area_sqft`.
  - Exclude `assessed_value <= 0` parcels from value-based component scoring.
  - Add guardrails so very small parcels do not dominate (`min_area_sqft` threshold and winsorization of psf metric).
- Rebuild shortlist table UX:
  - Cluster-only top list.
  - Scrollable embedded table in integration QMD.
  - Business-first columns (`zone_label`, `parcel_uid`, subtype, area, value_psf, component scores, final score).
- Finish with a map of top shortlisted parcels overlaid on cluster zones and context layers.

### Section 5 Execution Plan
1. Cluster-only data pipeline
- Update `section_05_build.R` to stop producing/consuming contiguity outputs for narrative artifacts.
- Preserve contiguity internals only if required by downstream checks, but do not expose in visuals/QMD.

2. New context maps (cluster narrative sequence)
- Build `market_parcel_context_map` (residential + retail parcels, no shortlist filter).
- Build `cluster_parcel_overlay_map` (cluster polygons + parcel context).
- Reuse Section 02 context layers (roads/water/places/county/CBSA) for visual consistency.

3. Parcel scoring refactor (value normalization)
- Add derived fields:
  - `assessed_value_clean` (`NA` when `<= 0`)
  - `assessed_value_psf`
  - capped/winsorized value psf percentile for scoring robustness
- Update parcel characteristic component to use value-density signal instead of raw assessed value.
- Add explicit QA counters: dropped zero-value parcels, missing-area parcels, capped-psf counts.

4. Shortlist table and map refresh
- Rebuild cluster-only top table and top-parcel map from updated scores.
- Add table-ready display fields (formatted currency/psf, compact component columns).

5. Validation and integration
- Update `section_05_checks.R` for new fields and exclusion logic.
- Update `section_05_visuals.R` object contract for cluster-only visuals.
- Update integration QMD Section 5 chunks and required visual keys.
- Re-run Section 06 build/checks/visuals after Section 5 schema changes.

### Execution Status (Current Iteration)
- Part 1 complete: `section_05_build.R` and `section_05_checks.R` now run cluster-only artifacts (contiguity outputs removed from Section 05 build/check flow).
- Part 2 complete: `section_05_visuals.R` now adds two new maps:
  - `market_parcel_context_map` (residential/other + retail parcel pattern across market),
  - `cluster_parcel_overlay_map` (cluster zones over parcel context),
  both with Section 02/03 style roads/water/place/county/CBSA context.
- Part 3 complete: parcel value scoring now uses `JV` (Just Value) as primary value signal with area guardrails and winsorized `value_psf`; `SALE_PRC1` remains available for recency/sales context.
- Part 4 complete: cluster shortlist table/map refreshed to business-first fields (`just_value`, `value_psf`, recent sale fields) and top-parcel map now includes full market context layers.
- Part 5 complete: integration QMD updated to cluster-only Section 5 flow, new visual object keys wired, Section 06 rebuilt, and full Quarto render passed.
- New output images:
  - `sections/05_parcels/outputs/section_05_market_parcel_context_map.png`
  - `sections/05_parcels/outputs/section_05_cluster_parcel_overlay_map.png`

### RStudio Test Run (Section-Only)
```r
source("notebooks/retail_opportunity_finder/sections/05_parcels/section_05_build.R")
source("notebooks/retail_opportunity_finder/sections/05_parcels/section_05_checks.R")
source("notebooks/retail_opportunity_finder/sections/05_parcels/section_05_visuals.R")
```

### Dependencies
- Section 04 cluster artifacts are now the required upstream zone input.
- Section 05 build/check/visual updates.
- Integration QMD Section 5 rewrite (cluster-only flow).
- Section 06 refresh (depends on Section 05 artifacts).

### Upstream needs
- Confirm parcel value semantics by county/source:
  - Is `0` true value or missing/default placeholder?
  - Are there county-specific null/zero conventions?
- Confirm parcel area source quality (`parcel_area_sqft`) and missingness thresholds.
- Define preferred value metric fallback when assessed values are unavailable:
  - optional `sale_price_psf` fallback,
  - or keep `value_psf` as optional/non-blocking component with explicit NA handling.
- Confirm retail/residential land use mapping coverage before using parcel context map for corridor narrative.

### Additional Items You May Be Missing
- Performance: full-market parcel maps can be heavy; add stratified sampling or geometry simplification for render speed.
- Legend/readability: separate symbol treatment for residential vs retail parcel context layers.
- Assignment QA: track and report cluster parcel assignment coverage and unassigned parcels.
- Stability QA: compare top-50 shortlist before/after value-psf refactor to quantify ranking shift.

## Cross-Cutting Dependencies and Contracts

## Contract updates required
- `sections/OUTPUT_CONTRACTS.md` must be updated for any new/changed Section 02-06 artifacts.
- Integration manifest in `integration/qmd/retail_opportunity_finder_mvp.qmd` must reflect changed object names.

## Validation updates required
- Section 03 checks must validate score-all-tracts behavior.
- Section 05 checks must validate assessed value policy and shortlist score stability.
- Section 06 checks should verify references still valid after upstream output changes.

## Render/runtime constraints
- Notebook remains artifact-only at render time (`readRDS` + static files).
- No section build/check scripts executed by QMD render.

## Recommended Execution Sequence
1. Upstream data/features: add income metric + assessed value policy decision.
2. Section 03 redesign (build -> checks -> visuals).
3. Section 05 data/scoring fix (build -> checks -> visuals).
4. Section 02/04 visual and narrative improvements.
5. Section 06 refresh for updated upstream outputs.
6. Integration update in MVP QMD and full render.
7. Final QA pass and comparison summary.

## Definition of Done
- Business-first narrative in Sections 1-5 is readable by non-technical stakeholders.
- Score-all-tracts model implemented with configurable gates/variables.
- `median_income` integrated (or explicitly deferred with documented rationale).
- Section 5 shortlist no longer dominated by zero-assessed-value artifacts due to data handling bug.
- Map context improved across Sections 3-5 with local/static context layers.
- Full notebook render passes artifact-only policy and validation checks.

## Review Sprint R1 (Planning Only, No Build Yet)

### Objective
Capture final review feedback as scoped exploration tasks and alignment decisions before additional implementation.

### Working rule
- This sprint is analysis/planning only.
- No code refactor or visual rebuild work starts until decisions below are aligned.

### 1) Navigation/TOC rendering investigation
#### Questions to resolve
- Why does TOC fail to appear in the rendered viewer for current output?
- Is this a Quarto theme/layout behavior, RStudio viewer behavior, or heading-depth issue?

#### Exploration tasks
- Validate TOC visibility in three contexts: RStudio Viewer, browser-opened HTML file, and rendered document with alternate `toc-location` options.
- Inspect heading hierarchy consistency (`##` vs `###`) to confirm anchor generation.
- Test whether section numbering or template CSS is suppressing TOC pane.

#### Decision checkpoint
- Confirm final TOC strategy (left sidebar vs right vs floating) and render target behavior we optimize for.

### 2) Market Overview review tasks
#### Issues raised
- Primary vs secondary highways are visually too similar.
- Pop growth tile still references 5-year framing and subtitle text renders malformed arrow encoding.

#### Exploration tasks
- Propose 2-3 road-style schemes (line width, color hue, linetype, opacity) with accessibility checks.
- Audit Section 02 KPI source field and label contract for growth horizon consistency (3y vs 5y).
- Trace subtitle encoding path and confirm UTF-8-safe copy string policy.

#### Decision checkpoint
- Approve a single road symbology standard for Sections 02/03/04/05.
- Approve one growth horizon label standard for the full notebook.

### 3) Eligibility and Scoring review tasks
#### Issues raised
- Formula/weights visuals are redundant and unclear.
- “What this means” language still references gate-qualified tracts.
- Tract score histogram may have low narrative value.
- Clarify how Top-Tract Score Drivers is computed and why income can be negative.

#### Exploration tasks
- Replace dual formula display with one compact “variables + weight + sign” table/graphic pattern.
- Redraft Section 3 interpretation bullets for score-first narrative (not gate-first).
- Evaluate whether histogram adds decision value; recommend keep/remove with rationale.
- Document exact Top-Tract Score Drivers method: population used, averaging logic, sign interpretation, and z-score contribution behavior.

#### Decision checkpoint
- Approve final Section 3 visual package (required vs appendix diagnostics).
- Approve final copy language for score interpretation and income contribution explanation.

### 4) Zone Systems review tasks
#### Issues raised
- Cluster map is good but road classes still hard to distinguish.

#### Exploration tasks
- Apply same candidate road-style options from Section 02 and compare legibility on cluster map backgrounds.
- Validate visual consistency rules for county/place boundaries and water overlays.

#### Decision checkpoint
- Lock map styling token set shared across Sections 02–05.

### 5) Retail Overlay and Shortlist review tasks
#### Issues raised
- Clarify parcel-to-zone assignment-rate definition.
- Improve parcel visibility and legend readability (retail vs residential).
- Clarify “Cluster quality” meaning (is it mean tract score?).
- Remove/replace low-value “Retail area density” view.
- Enforce more balanced shortlist representation by cluster.
- Add richer parcel metadata in top table.

#### Exploration tasks
- Define and document assignment-rate denominator and numerator in business terms.
- Prototype parcel symbol hierarchy:
  - larger retail points,
  - stronger color contrast,
  - legend override with larger key glyphs.
- Rename “Cluster quality” if it maps to mean tract score percentile; align label to metric definition.
- Evaluate removal of retail area density view and candidate replacement.
- Test shortlist policy options:
  - top-N overall + minimum N per cluster,
  - strict top-10 per cluster,
  - hybrid quota with score thresholds.
- Define expanded metadata columns for table (ownership/situs/sales/use fields as available and reliable).

#### Decision checkpoint
- Approve shortlist policy (global rank vs per-cluster floor).
- Approve final Section 5 map set and table schema.

### 6) Conclusion and Appendix review tasks
#### Issues raised
- Add a “Future Deep Dives” subsection.

#### Exploration tasks
- Draft a compact future work section including:
  - retail density diagnostics,
  - retail-corridor-first clustering,
  - sensitivity analysis for score weights,
  - alternate parcel marketability signals.
- Define which items are near-term vs long-term.

#### Decision checkpoint
- Approve final future deep-dive list and prioritization tiering.

### Sprint outputs expected (planning artifacts only)
- A decision log with approved options per section.
- A revised implementation backlog grouped by “quick visual/copy fixes” vs “method changes”.
- Updated execution sequence for the next build sprint.

### Decision Checklist (Alignment Gate)
- [x] TOC behavior target is approved (browser is source of truth for acceptance).
- [ ] Shared road styling standard is approved (test two styles first; then lock one).
- [x] Section 02 growth horizon labels are approved (Option A: keep metro 5y metric, fix copy/encoding).
- [x] Section 03 formula/weights visual is approved (replace formula block with compact scorecard).
- [x] Section 03 “What this means” copy is approved for score-first language.
- [x] Decision made on tract score histogram (move to Appendix diagnostics).
- [x] Top-Tract Score Drivers method explanation is approved (add concise method note).
- [x] Section 05 assignment-rate definition is approved (business wording in narrative).
- [x] Section 05 “Cluster quality” label decision (use “Mean tract score percentile”).
- [x] Decision made on retail area density visual (remove from narrative render; keep code available).
- [x] Shortlist policy is approved (hybrid: top-N with per-cluster floor).
- [ ] Top parcel table schema is approved (add owner/address + original code mapping; finalize during refactor).
- [x] “Future Deep Dives” subsection scope is approved (near-term vs long-term structure).

### Decision Log (Approved)
- TOC: browser-rendered HTML is acceptance target.
- Roads: run side-by-side style test in section scripts before final lock.
- Growth horizon: keep 5-year metro KPI in Section 02 for now; fix subtitle rendering and consistency wording.
- Section 3: remove formula block and keep one compact weights/sign representation; update copy to score-first language.
- Section 3 histogram: move to Appendix diagnostics.
- Section 3 component driver chart: keep and add method explanation.
- Section 5 assignment rate: define clearly as share of retail-flagged parcels assigned into cluster zones.
- Section 5 metric naming: rename “Cluster quality” to “Mean tract score percentile”.
- Section 5 retail area density visual: remove from narrative flow for now (retain code paths for future reuse).
- Section 5 ranking policy: use hybrid shortlist logic with minimum per-cluster representation.
- Section 5 table enrichment: include owner/address details and original use code mapping context; finalize exact column set after field availability check.
- Section 6: add “Future Deep Dives” subsection with near-term vs long-term split.

### Build Order (No Final Render Yet)
1. Section 02 road-style A/B test outputs + growth tile subtitle fix.
2. Section 03 narrative and visual package cleanup (scorecard table, score histogram moved to appendix, driver-method note).
3. Section 05 shortlist refactor (hybrid selection, label updates, remove retail-density render, enrich table metadata).
4. Section 06 add Future Deep Dives subsection.
5. Section-level test runs only; hold full integration render until all above are reviewed.
