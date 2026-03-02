# Sprint C Overview - Section 04 Zones

## Objective
Convert ranked tracts from Sprint B into contiguous, interpretable zones with summary metrics and map-ready outputs.
Shared workflow reference: `notebooks/retail_opportunity_finder/sections/_shared/AGENT_INSTRUCTIONS.md`

## Task Breakdown

1. Load and validate Sprint B inputs
- Read:
  - `section_03_scored_tracts.rds`
  - `section_03_tract_sf.rds`
- Confirm one-row-per-tract assumptions.
- Validate join keys (`tract_geoid`) and geometry readiness.

2. Define zone candidate universe
- Use all tracts that pass gates (`eligible_v1 == 1`) as zone candidates.
- Do not limit candidate set to top-performing tracts within eligible set.
- Persist exact eligible tract list used for zoning for reproducibility.

3. Build tract contiguity graph
- Compute adjacency among selected tracts.
- Build connected components from adjacency graph.
- Assign component IDs as draft zone IDs.

4. Generate zone geometries
- Dissolve tracts by component ID.
- Compute geometry attributes (area, centroid/label point).
- Apply deterministic labels (`Zone A`, `Zone B`, ...).

5. Build zone summary metrics
- Produce zone-level KPIs:
  - tract count
  - total population
  - weighted growth
  - density summary
  - units per 1k
  - price proxy percentile
  - optional average tract score
- Include raw and display-ready fields.

6. Create zone visuals
- Zone map with labels.
- Optional map overlay of eligible tracts.
- Zone summary table.

7. Implement checks/QA
- Ensure all eligible tracts are assigned to exactly one zone.
- Ensure no duplicate tract assignment.
- Validate dissolved geometries (`st_is_valid`, non-empty).
- Check zone count target band (~3-8), warn if outside.
- Save validation report artifact.

8. Persist Sprint C artifacts
- `section_04_zones.rds`
- `section_04_zone_summary.rds`
- visual objects and/or PNG outputs
- validation report

## Requirements and Dependencies

### Data dependencies (required before build)
- `section_03_scored_tracts.rds`
- `section_03_tract_sf.rds`
- Required fields:
  - `tract_geoid`, `eligible_v1`
  - aggregation inputs (population, growth, density, units, price proxy)

### Method decisions to lock up front
- Selection rule: all gate-passing tracts (`eligible_v1 == 1`).
- Adjacency rule: `touches` vs `intersects`.
- Zone ordering rule (for stable labels).
- KPI aggregation rule by metric (weighted mean vs median).

### Geometry/topology dependencies
- Use projected CRS for area/centroid operations.
- Define invalid geometry policy (`st_make_valid` vs fail-fast).
- Define handling for single-tract or island zones.

### Contract dependencies
- Ensure output contracts include all Section 04 artifacts needed by Section 05.
- Keep schema stable for downstream parcel overlay joins.

### QA acceptance criteria
- 100% of eligible tracts assigned exactly once.
- Zone geometry valid and non-empty.
- Zone summary row count equals zone geometry row count.
- Zone count in expected range or explicit warning.
- Deterministic results across reruns with same inputs.

## Planned Execution Order
1. Confirm method decisions + dependencies.
2. Implement `section_04_build.R`.
3. Implement `section_04_checks.R`.
4. Implement `section_04_visuals.R`.
5. Run build/checks/visuals sequentially.
6. Update build plan checkpoint and output contracts.

## New Submodule: Cluster Zones (Extension)

### Purpose
Add a second zone type based on spatial clustering so nearby tracts can be grouped even when polygons do not directly touch.

### Submodule files
- `section_04_cluster_build.R`
- `section_04_cluster_checks.R`
- `section_04_cluster_visuals.R`

### Inputs and dependencies
- `section_04_zone_input_candidates.rds` (eligible tract `sf` + scoring fields)
- `section_04_zones.rds` and `section_04_zone_summary.rds` (for side-by-side comparison)
- Projected CRS for distance operations (recommended: EPSG:3086)

### Method (v1)
1. Compute tract centroids in projected CRS.
2. Build feature matrix from centroid coordinates (`x`, `y`).
3. Run DBSCAN clustering with configurable parameters:
  - `eps_meters`
  - `min_pts`
4. Handle noise points with full-coverage rule:
  - default: convert noise to singleton clusters.
5. Assign deterministic labels (`Cluster Zone A`, `Cluster Zone B`, ...):
  - order by `mean_tract_score` desc, tie-break on raw cluster id.
6. Dissolve polygons by cluster zone id into cluster-zone geometries.

### Parameters to lock before implementation
- `eps_meters` (initial test range: 5000-8000)
- `min_pts` (initial default: 3)
- noise handling rule (singleton clusters)
- label ordering rule (deterministic by score + id)

### Planned outputs
- `section_04_cluster_assignments.rds`
- `section_04_cluster_zones.rds`
- `section_04_cluster_zone_summary.rds`
- `section_04_cluster_visual_objects.rds`
- `section_04_cluster_zone_map.png`
- `section_04_cluster_validation_report.rds`

### QA acceptance criteria
- 100% eligible tracts assigned exactly once.
- Cluster zone geometries valid and non-empty.
- Cluster summary row count equals cluster geometry row count.
- Deterministic cluster labels across reruns with same params.
- Comparison stats logged vs contiguity zones:
  - zone count
  - median tracts/zone
  - mean zone score

### Integration notes
- Keep contiguity zones and cluster zones as parallel outputs (no overwrite).
- Update `OUTPUT_CONTRACTS.md` with cluster artifacts once implemented.
- Add side-by-side maps and comparison table in Section 04 visuals.
