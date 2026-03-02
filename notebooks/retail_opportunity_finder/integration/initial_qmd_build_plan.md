# Retail Opportunity Finder - Initial QMD Build Plan

## Goal
Build an initial, end-to-end `retail_opportunity_finder_dash_v1.qmd` that follows the intended funnel story:
**Funnel -> Rank -> Cluster -> Shortlist -> Action**

This plan uses:
- `notebooks/retail_opportunity_finder/retail_opportunity_finder_notebook_flow.md`
- `notebooks/retail_opportunity_finder/integration/sprint_f_checklist.md`
- existing section modules (`sections/01` through `sections/06`)

## Current Section Readiness (Analysis of 6 built sections)

### Section 01 - Setup
- Build/check outputs exist and are usable for runtime metadata + model dictionary.
- Key artifacts:
  - `section_01_run_metadata.rds`
  - `section_01_foundation.rds`
  - `section_01_validation_report.rds`
- Integration role: global preamble + assumptions anchors.

### Section 02 - Market overview
- Already modularized and validated; visuals are notebook-ready.
- Key artifacts:
  - `section_02_kpi_tiles.rds`
  - `section_02_peer_table.rds`
  - `section_02_benchmark_table.rds`
  - `section_02_pop_trend_indexed.rds`
  - `section_02_distribution_long.rds`
  - `section_02_visual_objects.rds`
- Integration role: opening context and thesis framing.

### Section 03 - Eligibility and scoring
- Fully implemented with funnel, scoring components, why-tags, visuals, and checks.
- Key artifacts:
  - `section_03_funnel_counts.rds`
  - `section_03_scored_tracts.rds`
  - `section_03_top_tracts.rds`
  - `section_03_tract_component_scores.rds`
  - `section_03_visual_objects.rds`
  - `section_03_validation_report.rds`
- Integration role: model transparency and tract-level evidence.

### Section 04 - Zones (contiguity + cluster extension)
- Both zoning systems are available and validated.
- Key artifacts:
  - contiguity: `section_04_zones.rds`, `section_04_zone_summary.rds`, `section_04_visual_objects.rds`
  - cluster: `section_04_cluster_zones.rds`, `section_04_cluster_zone_summary.rds`, `section_04_cluster_visual_objects.rds`, `section_04_cluster_vs_contiguity_comparison.rds`
- Integration role: convert ranked tracts into actionable submarkets.
- Known warning to surface in notebook caveats: contiguity zone count is `16` (outside target band `3-8`).

### Section 05 - Parcels and shortlist
- Dual-system overlays and shortlist scoring are implemented and pass hard checks.
- Key artifacts:
  - `section_05_zone_overlay_contiguity.rds`
  - `section_05_zone_overlay_cluster.rds`
  - `section_05_parcel_shortlist_contiguity.rds`
  - `section_05_parcel_shortlist_cluster.rds`
  - `section_05_visual_objects.rds`
  - `section_05_validation_report.rds`
- Integration role: bridge geography to concrete parcel candidates.
- Warnings to explicitly disclose:
  - parcel->zone assignment rate ~`0.257` for both systems
  - invalid shortlist geometries present (`207`)

### Section 06 - Conclusion and appendix
- Conclusion payload, appendix payload, and visual objects are complete and validated.
- Key artifacts:
  - `section_06_conclusion_payload.rds`
  - `section_06_appendix_payload.rds`
  - `section_06_visual_objects.rds`
  - `section_06_validation_report.rds`
- Integration role: final decision framing + assumptions/QA rollup.

## Proposed Initial Notebook Structure

## 1. Setup and methodology

### Story objective
State what the notebook does, what question it answers, and how the funnel works.

### Copy (draft)
- Paragraph 1: "This report identifies where retail corridor opportunity is strongest in Jacksonville by screening tracts, forming zones, and ranking parcel candidates."
- Paragraph 2: "The model emphasizes demand momentum (growth), development pressure (supply), headroom, and price pressure guardrails, then translates tract signals to zone and parcel actions."

### Visual/content blocks
- Run metadata mini table (from Section 01).
- KPI/assumption dictionary excerpt (from Section 01).

## 2. Metro context (Section 02)

### Story objective
Show why Jacksonville is a plausible market before tract-level selection.

### Copy (draft)
- Lead sentence: "Jacksonville shows the profile of a market where corridor expansion may be supported by both growth and housing pipeline momentum."
- 3-5 bullets after visuals describing signal strength and tradeoffs.

### Visual sequence
1. KPI tile row (population, 5y growth, units/1k, rent, home value, commute)
2. Peer ranking table
3. Benchmark table (JAX vs South Atlantic vs US)
4. Indexed population trend line
5. Metro distribution facets with JAX highlight

## 3. Eligibility funnel and tract scoring (Section 03)

### Story objective
Make screening logic auditable and score construction easy to inspect.

### Copy (draft)
- Explain gates as "false-positive protection" (growth, price, density).
- Include explicit weighted score formula and one-sentence rationale for z-scoring within metro.

### Visual sequence
1. Funnel table (with % retained)
2. Price proxy histogram + 70th percentile line
3. Growth histogram + median line
4. Eligibility map (binary)
5. Score histogram
6. Growth vs density scatter with top tracts highlighted
7. Top tract table with why tags and component contributions

## 4. Zone systems and submarket definition (Section 04)

### Story objective
Translate top tracts into operationally usable zone geographies.

### Copy (draft)
- Introduce both methods briefly:
  - Contiguity zones: strict touching polygons
  - Cluster zones: distance-based grouping for near-but-not-touching tracts
- Set default narrative mode to **cluster**, with contiguity as comparison.

### Visual sequence
1. Cluster zone map with labels (primary)
2. Cluster zone summary table (primary)
3. Contiguity vs cluster comparison table
4. Contiguity zone map/table in collapsible/details block (secondary)

## 5. Retail overlay and parcel shortlist (Section 05)

### Story objective
Move from "which places" to "which parcels".

### Copy (draft)
- Explain shortlist score components and weights:
  - `0.50 zone_quality + 0.25 local_retail_context + 0.25 parcel_characteristics`
- Explain boundary policy (strict in-zone) and what that implies for coverage.

### Visual sequence
1. Cluster zone overlay summary table (retail count/density + zone quality)
2. Cluster shortlist map (primary)
3. Cluster top parcels table (top 25-50)
4. Contiguity overlay + shortlist map/table (secondary comparison)
5. Zone-system comparison table

## 6. Conclusion and appendix (Section 06)

### Story objective
End with decisions, next actions, and clear caveats.

### Copy (draft)
- Conclusion: top 3 cluster zones + why.
- Next actions: field validation, geometry repair workflow, boundary sensitivity, weight calibration.

### Visual/content blocks
1. Top cluster zones highlight table
2. Shortlist summary table
3. Recommended next actions table
4. Appendix:
  - KPI definitions
  - assumptions/caveats
  - section QA rollup

## Integration and Build Plan (Sprint F)

### Phase F1 - Preflight contracts
1. Validate required artifacts exist for Sections 03-06 (and Section 02 if fully wiring existing visuals).
2. Confirm validation pass status:
- Section 03 pass TRUE
- Section 04 pass TRUE (warning acknowledged)
- Section 05 pass TRUE (warnings acknowledged)
- Section 06 pass TRUE
3. Freeze object names consumed by QMD to avoid breaking references.

### Phase F2 - QMD scaffold and load layer
1. Add a single hidden setup chunk that reads all required `*.rds` artifacts.
2. Create section-level object aliases (e.g., `s03_visuals`, `s04_cluster_visuals`) for clean chunk code.
3. Add defensive checks (`stop()` with artifact-specific message) early in render.
4. Enforce runtime policy: notebook render is **read-only from artifacts** (`readRDS` and static assets only), with **no execution** of `section_*_build.R`, `section_*_visuals.R`, or `section_*_checks.R`.

### Phase F3 - Narrative + visual integration passes
1. Integrate Section 02 story blocks (if keeping current code, switch to artifact-driven render calls).
2. Integrate Section 03 blocks in order: gates -> score model -> diagnostics -> top tracts.
3. Integrate Section 04 blocks with cluster-first default + contiguity comparison.
4. Integrate Section 05 blocks with cluster-first parcel shortlist + comparison view.
5. Integrate Section 06 conclusion + appendix objects.

### Phase F4 - Render hardening
1. Run full render end-to-end.
2. Resolve runtime errors and object mismatches.
3. Normalize chunk labels, captions, units, and source notes.
4. Re-render until stable with no manual edits between runs.

### Phase F5 - Quality and caveat pass
1. Ensure warnings from Sections 04/05 are visible in appendix caveats.
2. Ensure model assumptions and boundary policy are explicitly stated near Section 05.
3. Ensure table/plot labeling consistency (percent vs fraction, currency precision, units per 1k).

### Phase F6 - Integration outputs
1. Updated `retail_opportunity_finder_dash_v1.qmd`
2. Integration validation summary saved under `integration/outputs/`
3. Optional artifact manifest (`integration/outputs/required_artifact_status.csv`)

## Recommended Build Order (single runbook)
1. Run section scripts in order for reproducible refresh: `01 -> 02 -> 03 -> 04 (+ cluster) -> 05 -> 06`.
2. Render QMD.
3. Run integration checklist (`sprint_f_checklist.md`) and mark status.
4. Save integration summary log.

## Key Risks to Manage During Initial QMD Build
- Output contracts updated for Sections 05/06; keep contracts and integration references synchronized for any new artifact additions.
- Section 04 contiguity zone count is above intended narrative band, so cluster should remain default.
- Section 05 invalid parcel geometries and zone assignment rates are acceptable for baseline, but must be transparent in caveats.

## Definition of Done for Initial Notebook
- Full notebook render succeeds without manual intervention.
- Sections 1-6 all present in one coherent narrative.
- Cluster-default zone and shortlist story is visible, with contiguity comparison retained.
- Assumptions and QA caveats are explicit in appendix and referenced in conclusion actions.
