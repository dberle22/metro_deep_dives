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

### Dependencies
- Section 02 visual objects update (`section_02_visuals.R`) and/or integration override chunk.
- Tract geometry artifact for full-market map source.

### Upstream needs
- If full-market map includes additional context layers (roads/water), add static layer artifacts in advance.

## 3) Section 3 Model Redesign (Score-First, Gate-Second)

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

### Objective
Explain zone construction in plain language and make system comparison decision-ready.

### Changes
- Add stepwise explanation of contiguity vs cluster methods.
- Clarify why cluster is default for MVP while retaining contiguity comparison.
- Tie method choice to business use (operational submarket targeting).

### Dependencies
- Section 04 comparison metrics and visual artifacts.
- Final language alignment with Section 5 shortlist narrative.

### Upstream needs
- None.

## 7) Section 5 Business Logic + Data Quality Fixes

### Objective
Make parcel shortlist explainable and correct potential scoring distortion from zero assessed values.

### Changes
- Rewrite parcel scoring explanation in business terms (zone quality, retail context, parcel traits).
- Define parcel-to-zone assignment rate clearly in notebook text.
- Add market-wide retail parcel context map before zone-specific corridor views.
- Fix assessed value treatment in scoring: convert invalid zeros to missing (or explicit policy), then handle via robust fallback.
- Revalidate top 50 table values after fix.

### Dependencies
- Section 05 build/check/visual update.
- Re-run Section 06 (uses Section 05 outputs in conclusion payload).

### Upstream needs
- Confirm source-system semantics for zero assessed value (true zero vs missing/default).
- If needed, add county/source quality flags into canonical parcel pipeline.

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
