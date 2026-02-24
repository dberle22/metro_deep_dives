# Section Output Contracts

This file defines expected outputs from each section module so `.qmd` integration can remain stable.

## General conventions
- Persist reusable objects as `.rds` under each section's `outputs/` folder.
- File naming pattern: `section_<xx>_<artifact_name>.rds`.
- Include a `generated_at` timestamp column/field where practical.
- Geospatial outputs should include explicit CRS metadata.

## Section contracts

### 01_setup
- `outputs/section_01_run_metadata.rds`
  - List with run metadata and selected parameters.
- `outputs/section_01_foundation.rds`
  - Shared foundations payload (KPI dictionary, model params, model parameter validation).
- `outputs/section_01_validation_report.rds`
  - Column/key/null/geometry validation report for primary notebook inputs.

### 02_market_overview
- `outputs/section_02_kpi_tiles.rds`
  - One-row data frame with metro KPI tile values.
- `outputs/section_02_peer_table.rds`
  - Data frame for peer ranking table.
- `outputs/section_02_benchmark_table.rds`
  - Data frame for JAX vs region vs US comparison.
- `outputs/section_02_pop_trend_indexed.rds`
  - Indexed population trend data for Jacksonville, South Atlantic, and U.S. CBSAs.
- `outputs/section_02_distribution_long.rds`
  - Long-format all-metro distribution dataset used for boxplot facets.
- `outputs/section_02_visual_objects.rds`
  - Render-ready UI/table/plot objects (tiles layout, gt tables, ggplots).
- `outputs/section_02_validation_report.rds`
  - Schema and logic checks for all Section 02 artifacts.

### 03_eligibility_scoring
- `outputs/section_03_funnel_counts.rds`
  - Funnel step counts through growth, price, density, and final eligibility gates.
- `outputs/section_03_eligible_tracts.rds`
  - Tract-level filtered set with eligibility flags.
- `outputs/section_03_scored_tracts.rds`
  - Tract-level scored set with component z-scores and weighted contributions.
- `outputs/section_03_top_tracts.rds`
  - Top-N tract table with rank and why-tags.
- `outputs/section_03_tract_component_scores.rds`
  - Full tract-level table with raw components, z-scores, weighted contributions, and final score/rank.
- `outputs/section_03_tract_component_scores.csv`
  - CSV export of tract-level component and score table for external review.
- `outputs/section_03_visual_objects.rds`
  - Render-ready Section 03 gt/ggplot objects.
- `outputs/section_03_validation_report.rds`
  - Section 03 schema, logic, and geometry validation report.

### 04_zones
- `outputs/section_04_zones.rds`
  - Zone geometry/object with zone IDs and labels.
- `outputs/section_04_zone_summary.rds`
  - Zone-level KPI summary table.

### 05_parcels
- `outputs/section_05_retail_intensity.rds`
  - Tract-level retail intensity metrics.
- `outputs/section_05_parcel_shortlist.rds`
  - Final parcel shortlist table/object.

### 06_conclusion_appendix
- `outputs/section_06_conclusion_points.rds`
  - Character vector or table of final conclusion bullets.
- `outputs/section_06_appendix_notes.rds`
  - Structured appendix notes (definitions, assumptions, caveats, QA summary).
