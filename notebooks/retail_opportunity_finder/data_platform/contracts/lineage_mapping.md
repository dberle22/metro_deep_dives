# Lineage Mapping

This is the first-pass lineage map for the ROF V2 transition.

## Reference And Membership Layer
- `ref.market_dim`
  - source: shared `MARKET_PROFILES`
  - consumers: all upstream workflows, notebook build orchestration
- `ref.market_county_membership`
  - source: `metro_deep_dive.silver.xwalk_cbsa_county` plus market profile state scope
  - consumers: foundation, zones, parcel, serving
- `ref.market_tract_membership`
  - source: `metro_deep_dive.silver.xwalk_tract_county`, `ref.market_county_membership`
  - consumers: foundation, scoring, zones, parcel-serving prep
- `ref.land_use_mapping`
  - source: `notebooks/retail_opportunity_finder/land_use_code_mapping.csv` plus the current reviewed Section 05 candidate overlay for retail classification fields
  - consumers: parcel standardization, retail classification, Section 05 transition
- `qa.ref_validation_results`
  - source: reference-layer QA checks against `ref.*` tables and the current Section 05 mapping-candidates artifact
  - consumers: QA review, lineage signoff, downstream readiness checks
- `qa.ref_unmapped_land_use_codes`
  - source: anti-join between `ref.land_use_mapping` and the current mapping-candidates artifact
  - consumers: parcel standardization review and land-use mapping maintenance

## Foundation Layer
- `foundation.cbsa_features`
  - source: existing `sql/features/cbsa_features.sql`
  - current downstream consumer: Section 02
- `foundation.tract_features`
  - source: existing `sql/features/tract_features.sql`
  - current downstream consumers: Section 02, Section 03, tract scoring workflow
- `foundation.market_tract_geometry`
  - source: DuckDB tract geometry helpers scoped by active market profile
  - current downstream consumers: Section 02, tract scoring, zone build
- `foundation.market_county_geometry`
  - source: DuckDB county geometry helpers scoped by active market profile
  - current downstream consumers: Section 02, visuals, parcel-serving prep
- `foundation.market_cbsa_geometry`
  - source: DuckDB CBSA geometry helpers scoped by active market profile
  - current downstream consumers: Section 02 context serving
- `qa.foundation_validation_results`
  - source: foundation layer schema/key/row checks
  - consumers: QA review and notebook-facing validation
- `qa.foundation_null_rates`
  - source: null-rate summaries on published foundation tables
  - consumers: QA review and source-of-truth decisions

## Scoring Layer
- `scoring.tract_scores`
  - sources: `foundation.tract_features`, scoring weights in shared config
  - downstream consumers: Section 03, zone build workflow, future serving prep
- `scoring.cluster_seed_tracts`
  - sources: `scoring.tract_scores`
  - downstream consumers: zone build workflow, future parcel prep

## Zone Build Layer
- `zones.zone_input_candidates`
  - sources: `scoring.cluster_seed_tracts`, `scoring.tract_scores`, tract geometry
  - downstream consumers: contiguity and cluster zone builders
- `zones.contiguity_zone_components`
  - sources: `zones.zone_input_candidates`
  - downstream consumers: contiguity geometry and summary outputs
- `zones.contiguity_zone_summary`
  - sources: `zones.zone_input_candidates`, `zones.contiguity_zone_components`
  - downstream consumers: Section 04, future market serving prep
- `zones.cluster_assignments`
  - sources: `zones.zone_input_candidates`
  - downstream consumers: Section 04 cluster visuals, Section 05, future serving prep
- `zones.cluster_zone_summary`
  - sources: `zones.zone_input_candidates`, `zones.cluster_assignments`
  - downstream consumers: Section 04, Section 05, future serving prep

## Transition Note
During this slice, Section 03 and Section 04 still emit `section_*` artifacts for downstream compatibility. Those artifacts are transitional derivatives of the upstream-prepared products rather than the intended long-term source of truth.

## Parcel Standardization Decision
- canonical parcel attributes should reuse the existing DuckDB parcel tables where available
- parcel geometry should continue to come from the existing county analysis `.RDS` artifacts
- Section 05 may therefore consume a split contract during transition:
  - DuckDB for tabular parcel-serving inputs
  - `.RDS` for geometry-bearing parcel analysis inputs
- where block GEOIDs exist on parcel or related source records, tract GEOIDs should be derived from the first 11 characters rather than relying on a separate block-to-tract reference table

## Parcel Layer
- `parcel.parcels_canonical`
  - sources: `rof_parcel.parcel_tabular_clean`, `ref.market_county_membership`
  - downstream consumers: Section 05, future market serving prep
- `parcel.parcel_join_qa`
  - sources: `parcel_geometry_join_qa_county_summary.rds`, `ref.market_county_membership`
  - downstream consumers: Section 05 readiness checks, parcel QA review
- `parcel.parcel_lineage`
  - sources: `parcel.parcel_join_qa`, `rof_parcel.parcel_county_load_log`, `parcel.parcels_canonical`
  - downstream consumers: QA review, release operations, county troubleshooting
- `parcel.retail_parcels`
  - sources: `parcel.parcels_canonical`, `ref.land_use_mapping`
  - downstream consumers: Section 05 retail intensity and shortlist prep
- `qa.parcel_validation_results`
  - sources: `parcel.*` tables and market county coverage checks
  - downstream consumers: QA review and release signoff
- `qa.parcel_unmapped_use_codes`
  - sources: anti-join between `parcel.parcels_canonical` and `ref.land_use_mapping`
  - downstream consumers: mapping maintenance and parcel classification review
