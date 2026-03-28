# Sprint D Overview - Section 05 Parcels

## Objective
Build the retail corridor overlay and parcel shortlist module using **both Section 4 zone systems** as candidate geography:
- Contiguity zones (`section_04_zones.rds`)
- Cluster zones (`section_04_cluster_zones.rds`)

The module should produce tract-level retail intensity, parcel-level shortlist outputs, and comparison-ready artifacts by zone system.

## Agent Instructions

Use this workflow before and during each Sprint D implementation step to reduce rework and catch issues early.
Canonical shared reference: `notebooks/retail_opportunity_finder/sections/_shared/AGENT_INSTRUCTIONS.md`

### 1) Preflight contract lock
- Define exact input artifacts and expected schemas before coding.
- Define required keys and uniqueness constraints up front.
- Confirm output artifact names/paths before implementation.

### 2) Spatial CRS policy
- Keep storage CRS checks against `GEOMETRY_ASSUMPTIONS$expected_crs_epsg` (currently `4326`).
- Run all spatial operations (joins, intersections, area, point-on-surface) in `GEOMETRY_ASSUMPTIONS$analysis_crs_epsg` (currently `5070`).
- Normalize all `sf` inputs to analysis CRS before any spatial operation.

### 3) Readiness checks before transforms
- Validate required columns for every upstream artifact.
- Validate key uniqueness for all join keys.
- Validate geometry object type, CRS, and empty geometry policy.
- Fail fast on hard-check failures before downstream computation.

### 4) Build execution pattern
- Implement transforms in small, deterministic steps.
- Persist intermediate artifacts at step boundaries.
- Include explicit score component columns before any final composite score.
- Use deterministic ranking/tie-break rules for shortlist outputs.

### 5) Validation and reporting
- Persist a step-level validation report (`*_report.rds`) with:
  - schema checks
  - key checks
  - geometry checks
  - row/coverage counts
  - pass/fail status
- Treat warnings (for example geometry validity sample counts) as explicit report fields.

### 6) Communication protocol for future runs
- Before coding each step, restate:
  - target step scope
  - required inputs
  - expected outputs
  - blocking assumptions
- After execution, report:
  - produced artifacts
  - key row counts/coverage
  - pass/fail status
  - any warnings and next mitigation action

## Scope for Sprint D
1. Standardize parcel tabular + spatial data in an upstream workspace.
2. Overlay parcel signal with both zone systems.
3. Build parcel shortlist candidates inside target zones.
4. Publish map/table outputs for both zone systems.
5. Validate assignment coverage, geometry, and shortlist logic.

## Locked Decisions (As Of Sprint D Kickoff)

### 1) Zone-system strategy (locked)
- Run both zone systems in parallel with explicit `zone_system` field (`contiguity`, `cluster`).
- Default Section 05 narrative view: `cluster`.
- Keep comparison-ready outputs for both systems in all core artifacts.

### 2) Retail parcel definition (locked for v0.1 baseline)
- Inclusion policy: `retail-only` parcels for shortlist eligibility.
- Maintain a versioned mapping table: `land_use_code -> retail_flag` (+ optional `retail_subtype`).
- Approved mapping set:
  - core retail: `011`, `012`, `013`, `014`, `015`, `016`, `021`, `022`
  - retail-adjacent commercial (approved include): `010`, `026`, `027`, `028`, `033`, `034`

### 3) Shortlist ranking logic (locked framework)
- Shortlist score components:
  - zone quality score (from Section 03/04 tract and zone outputs)
  - local retail context score (Section 05 derived)
  - parcel characteristics score (Section 05 derived)
- Locked baseline weights:
  - `shortlist_score = 0.50 * zone_quality_score + 0.25 * local_retail_context_score + 0.25 * parcel_characteristics_score`
- Implement score components as explicit, persisted fields in build outputs.

### 4) Inclusion boundary policy (locked)
- Use strict in-zone intersection for Sprint D baseline.
- No boundary buffer in baseline run.
- Buffer option can be added as a sensitivity mode after baseline validation.

## Detailed Execution Plan

### Step 1 - Input readiness and schema checks
- Load zone artifacts:
  - `../04_zones/outputs/section_04_zones.rds`
  - `../04_zones/outputs/section_04_zone_summary.rds`
  - `../04_zones/outputs/section_04_cluster_zones.rds`
  - `../04_zones/outputs/section_04_cluster_zone_summary.rds`
- Confirm geometry validity, CRS compatibility, unique IDs.
- Standardize both systems to common schema:
  - `zone_system`, `zone_id`, `zone_label`, `geometry`.

### Step 2 - Parcel source ingestion and normalization
- Run the manual county parcel ETL:
  - `parcel_standardization/parcel_etl_manual_county_v2.R`
- Load standardized outputs from:
  - DuckDB table `rof_parcel.parcel_tabular_clean`
  - county geometry `.rds` files under `property_taxes/parcel_geom/<state>/`
- Required minimum columns:
  - `parcel_id`
  - `geometry`
  - `land_use_code` (or equivalent)
- Preferred columns:
  - `parcel_area`
  - `assessed_value`
  - `last_sale_date`
  - `last_sale_price`
- Normalize types and names in a single canonical parcel table.

### Step 3 - Retail classification
- Apply land-use mapping to create:
  - `retail_flag`
  - optional `retail_subtype`
- Save mapping + classified parcel table for reproducibility.

### Step 4 - Tract-level retail intensity
- Spatially join parcels -> tracts.
- Compute metrics by tract:
  - `retail_parcel_count`
  - `retail_area`
  - `retail_area_density` (`retail_area / tract_land_area_sqmi`)
- Persist intensity dataset.

### Step 5 - Zone overlays (both systems)
- Join tract-level retail intensity to:
  - contiguity zones
  - cluster zones
- Aggregate zone-level retail context metrics for each zone system.

### Step 6 - Parcel shortlist candidates
- Intersect parcels with each zone system.
- Produce candidate parcel table with:
  - parcel attrs
  - `zone_system`, `zone_id`, `zone_label`
  - zone score context
  - local retail intensity context
- Build shortlist score and rank within each zone system.
  - add `local_retail_context_score`
  - add `parcel_characteristics_score`
  - add `shortlist_score`

### Step 6A - Local retail context score workflow
- Build parcel-neighborhood retail context features (within same zone system):
  - tract retail intensity of assigned tract
  - optional nearby retail count/density proxy within tract or nearest-neighbor radius
- Standardize to comparable scale (e.g., percentile rank or z-score).
- Baseline scoring definition (v0.1):
  - `pctl_tract_retail_parcel_count`
  - `pctl_tract_retail_area_density`
  - `local_retail_context_score = 0.5 * pctl_tract_retail_parcel_count + 0.5 * pctl_tract_retail_area_density`
- Persist:
  - `local_retail_context_score`
  - feature-level component columns used to derive it

### Step 6B - Parcel characteristics score workflow
- Build parcel-level feature set:
  - `parcel_area` (or geometry-derived area fallback)
  - `assessed_value` (prefer `total_value`; fallback `land_value`)
  - sales recency from sale year/month fields (`sale_yr1`, `sale_mo1`)
- Standardize each component to a common scoring scale.
- Baseline scoring definition (v0.1):
  - `pctl_parcel_area` (higher is better)
  - `pctl_assessed_value` (lower is better via inverse percentile)
  - `pctl_sale_recency` (more recent is better)
  - `parcel_characteristics_score = 0.4 * pctl_parcel_area + 0.3 * inv_pctl_assessed_value + 0.3 * pctl_sale_recency`
- Combine into `parcel_characteristics_score`.
- Persist component columns and final score for auditability.

### Step 6C - Final shortlist score workflow
- Join all score components at parcel-zone grain:
  - `zone_quality_score`
  - `local_retail_context_score`
  - `parcel_characteristics_score`
- Compute:
  - `shortlist_score = 0.50 * zone_quality_score + 0.25 * local_retail_context_score + 0.25 * parcel_characteristics_score`
- Rank parcels within each `zone_system` and persist rank columns.

### Step 7 - Visual outputs
- For each zone system:
  - map: zones + retail parcels/intensity
  - map: shortlisted parcels
  - table: top 25-50 parcels
- Add compact comparison table between zone systems.

### Step 8 - QA and validation
- Coverage checks:
  - parcel assignment rates
  - zone linkage completeness
- Geometry checks:
  - valid/non-empty shapes
  - CRS consistency
- Logic checks:
  - shortlist ranking reproducibility
  - no duplicate parcel-zone assignment unless expected by boundary rule
- Persist validation report.

## Data Readiness Analysis (Current State)

### Available now (ready)
1. Section 4 zone outputs are available and validated.
- Contiguity zones: `16`
- Cluster zones: `7`
- Supporting summaries and maps are present.

2. Section 3 tract outputs are available and validated.
- Includes tract scoring context needed for downstream parcel ranking.

### Missing / unresolved (blockers)
1. **External parcel source path must be configured**
- Raw files are in another project; Section 05 repo does not store them.
- Upstream standardization requires:
  - `PROPERTY_TAX_ROOT` (CSV + metadata)
  - `PROPERTY_SHAPE_ROOT` (shapefiles)

2. **Retail land-use mapping approved for v0.1**
- Mapping baseline is approved and versioned for implementation.

3. **Score weights approved for v0.1**
- Baseline component and composite weights are locked for initial build.

## Dependency Checklist Before Coding Section 05 Build
- [ ] `PROPERTY_TAX_ROOT` and `PROPERTY_SHAPE_ROOT` configured
- [ ] Parcel schema documented (required + optional fields)
- [x] Land-use retail mapping table finalized from v0.1 candidate
- [x] Final score weights approved for shortlist formula
- [x] Boundary policy approved (strict in-zone)

## Execution Checklist (Sprint D)

### D0 - Decision Lock (must complete first)
- [x] Confirm zone-system reporting mode:
  - [x] Dual-system outputs in Section 05 with side-by-side comparison
  - [x] Cluster default in narrative with contiguity retained in artifacts
- [x] Approve retail classification mapping (`land_use_code -> retail_flag`, optional subtype)
- [x] Approve shortlist score formula (weights + tie-break policy)
- [x] Approve inclusion boundary rule:
  - [x] Strict in-zone intersection only
  - [ ] Zone boundary buffer policy (distance in feet/meters)

### D1 - Input Readiness and Canonicalization (`section_05_build.R`)
- [x] Load and validate zone inputs from `../04_zones/outputs`
- [x] Standardize zone schema to: `zone_system`, `zone_id`, `zone_label`, `geometry`
- [x] Load standardized parcel outputs from `parcel_standardization/outputs/fl_all_v2`
- [x] Build canonical parcel table with required fields:
  - [x] `parcel_id`/`join_key`
  - [x] `geometry`
  - [x] `land_use_code`
- [x] Normalize preferred parcel fields when available:
  - [x] `parcel_area`
  - [x] `assessed_value`
  - [x] `last_sale_date`
  - [x] `last_sale_price`
- [x] Persist `outputs/section_05_parcels_canonical.rds`

### D2 - Retail Classification and Intensity (`section_05_build.R`)
- [x] Apply approved land-use mapping to create `retail_flag` (+ optional `retail_subtype`)
- [x] Persist classified parcels: `outputs/section_05_retail_classified_parcels.rds`
- [x] Spatial join parcels to tracts
- [x] Compute tract retail metrics:
  - [x] `retail_parcel_count`
  - [x] `retail_area`
  - [x] `retail_area_density`
- [x] Persist tract intensity: `outputs/section_05_retail_intensity.rds`

### D3 - Zone Overlays and Shortlist (`section_05_build.R`)
- [x] Overlay tract retail intensity with contiguity zones
- [x] Overlay tract retail intensity with cluster zones
- [x] Persist overlays:
  - [x] `outputs/section_05_zone_overlay_contiguity.rds`
  - [x] `outputs/section_05_zone_overlay_cluster.rds`
- [x] Build parcel-zone candidate table with zone context + local retail context
- [x] Apply approved shortlist score and rank by `zone_system`
- [x] Persist shortlist outputs:
  - [x] `outputs/section_05_parcel_shortlist_contiguity.rds`
  - [x] `outputs/section_05_parcel_shortlist_cluster.rds`

### D4 - Visuals (`section_05_visuals.R`)
- [x] Build map: zones + retail intensity (contiguity)
- [x] Build map: zones + retail intensity (cluster)
- [x] Build map: shortlisted parcels (contiguity)
- [x] Build map: shortlisted parcels (cluster)
- [x] Build top parcel tables (top 25-50) for both systems
- [x] Build compact comparison table (`contiguity` vs `cluster`)
- [x] Persist visual bundle: `outputs/section_05_visual_objects.rds`

### D5 - QA and Validation (`section_05_checks.R`)
- [x] Coverage checks:
  - [x] parcel -> tract assignment rate
  - [x] parcel -> zone assignment rate by `zone_system`
- [x] Geometry checks:
  - [x] valid/non-empty geometries
  - [x] CRS consistency across parcels/tracts/zones
- [x] Logic checks:
  - [x] deterministic shortlist ranking
  - [x] duplicate parcel-zone handling matches boundary policy
- [x] Persist `outputs/section_05_validation_report.rds`
- [x] Mark Sprint D complete only when validation report hard checks pass

### D6 - Notebook Integration (post-build)
- [ ] Wire Section 05 artifacts into `integration/qmd/retail_opportunity_finder_mvp.qmd`
- [ ] Add Section 05 narrative text for corridor signal + shortlist interpretation
- [ ] Ensure selected reporting mode (dual vs default+alt) is reflected consistently
- [ ] Run full render and resolve integration regressions

## Proposed Sprint D Artifacts
- `parcel_standardization/outputs/parcel_attributes_standardized.rds`
- `parcel_standardization/outputs/parcel_geometries_standardized.rds`
- `parcel_standardization/outputs/parcel_geometries_standardized.gpkg`
- `duckdb.parcel_attributes_standardized`
- `duckdb.parcel_geometries_standardized`
- `outputs/section_05_parcels_canonical.rds`
- `outputs/section_05_retail_classified_parcels.rds`
- `outputs/section_05_retail_intensity.rds`
- `outputs/section_05_zone_overlay_contiguity.rds`
- `outputs/section_05_zone_overlay_cluster.rds`
- `outputs/section_05_parcel_shortlist_contiguity.rds`
- `outputs/section_05_parcel_shortlist_cluster.rds`
- `outputs/section_05_visual_objects.rds`
- `outputs/section_05_validation_report.rds`

## Immediate Next Step
Run the upstream `parcel_standardization` scripts first, then wire Section 05 build scripts to consume the standardized outputs.
