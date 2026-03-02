# Cluster Zones Submodule Plan (Section 04)

## Purpose
Create a second zone type using spatial clustering so nearby tracts can be grouped even when they do not touch.
Shared workflow reference: `notebooks/retail_opportunity_finder/sections/_shared/AGENT_INSTRUCTIONS.md`

## Module Files
- `section_04_cluster_build.R`
- `section_04_cluster_checks.R`
- `section_04_cluster_visuals.R`

## Inputs
- `../outputs/section_04_zone_input_candidates.rds`
- `../outputs/section_04_zones.rds` (comparison)
- `../outputs/section_04_zone_summary.rds` (comparison)

## Method (v1)
1. Transform tract centroids to projected CRS (EPSG:3086).
2. Cluster centroids with DBSCAN (`eps_meters`, `min_pts`).
3. Convert noise points to singleton clusters for full tract coverage.
4. Assign deterministic cluster zone labels by descending mean tract score.
5. Dissolve candidate tract polygons by cluster zone id.

## Parameters to Lock
- `eps_meters` (initial: 5000-8000)
- `min_pts` (initial: 3)
- Noise policy: singleton cluster assignment
- Label ordering: score desc, tie-break cluster id

## Outputs
- `../outputs/section_04_cluster_assignments.rds`
- `../outputs/section_04_cluster_zones.rds`
- `../outputs/section_04_cluster_zone_summary.rds`
- `../outputs/section_04_cluster_visual_objects.rds`
- `../outputs/section_04_cluster_zone_map.png`
- `../outputs/section_04_cluster_validation_report.rds`

## QA Criteria
- All eligible tracts assigned exactly once.
- Cluster zone geometries valid and non-empty.
- Summary row count equals geometry row count.
- Deterministic labels with fixed params.
- Comparison stats vs contiguity zones (zone count, median tracts/zone, mean zone score).
