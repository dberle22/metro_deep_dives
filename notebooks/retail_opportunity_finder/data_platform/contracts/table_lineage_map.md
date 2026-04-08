# Table Lineage Map

This file is the canonical first-pass lineage map for the ROF V2 platform transition.

See also:
- `lineage_mapping.md` for the same lineage content in transition notes form.

## Market And Membership References

| Table | Grain | Direct parents | Notes |
| --- | --- | --- | --- |
| `ref.market_profiles` | `market_key` | `MARKET_PROFILES` config | Implemented source-backed reference table. |
| `ref.market_county_membership` | `market_key`, `county_geoid` | `silver.xwalk_cbsa_county`, `ref.market_profiles` | Implemented reusable county membership bridge. |
| `ref.market_cbsa_membership` | `market_key`, `cbsa_code`, `membership_type` | `ref.market_profiles` | Implemented target and peer relationship bridge. |
| `ref.county_dim` | `county_geoid` | `metro_deep_dive.geo.counties` | Implemented reusable county dimension. |
| `ref.tract_dim` | `tract_geoid` | `silver.xwalk_tract_county` | Implemented reusable tract dimension. Current scope still inherits the upstream `silver.xwalk_tract_county` state filter. |
| `ref.land_use_mapping` | `land_use_code` | `notebooks/retail_opportunity_finder/land_use_code_mapping.csv`, current reviewed Section 05 candidate overlay | Implemented governed land-use mapping table with retail classification fields. |
| `qa.ref_validation_results` | one row per QA check | `ref.*` tables, current Section 05 mapping candidates CSV | Implemented first-pass QA result table for the reference layer. |
| `qa.ref_geography_coverage` | `state_fips`, `state_abbr` | `ref.tract_dim` | Implemented state-level tract dimension coverage summary. |
| `qa.ref_unmapped_land_use_codes` | `land_use_code` | `ref.land_use_mapping`, current Section 05 mapping candidates CSV | Implemented unresolved land-use mapping coverage table. |

## Foundation

| Table | Grain | Direct parents | Notes |
| --- | --- | --- | --- |
| `foundation.cbsa_features` | `cbsa_code`, `year` | `data_platform/layers/01_foundation_features/tables/foundation.cbsa_features.sql` inputs | Implemented upstream publication in the foundation layer. The build file is an upstream asset; downstream should consume the published DuckDB table. |
| `foundation.tract_features` | `cbsa_code`, `tract_geoid`, `year` | `data_platform/layers/01_foundation_features/tables/foundation.tract_features.sql` inputs | Implemented upstream publication partitioned by `cbsa_code`. Current scope still inherits the upstream tract backbone. |
| `foundation.market_tract_geometry` | `cbsa_code`, `tract_geoid` | `data_platform/layers/01_foundation_features/tables/foundation.market_tract_geometry.sql` inputs | Implemented CBSA-keyed tract geometry-serving table with `geom_wkt`. Current source still inherits the upstream supported-state geometry table. |
| `foundation.market_county_geometry` | `cbsa_code`, `county_geoid` | `data_platform/layers/01_foundation_features/tables/foundation.market_county_geometry.sql` inputs | Implemented national county geometry-serving table with `geom_wkt`. |
| `foundation.market_cbsa_geometry` | `cbsa_code` | `data_platform/layers/01_foundation_features/tables/foundation.market_cbsa_geometry.sql` inputs | Implemented national CBSA geometry-serving table with `geom_wkt`. |
| `qa.foundation_validation_results` | one row per QA check | `foundation.*` tables | Implemented foundation QA result table. |
| `qa.foundation_geography_coverage` | `state_fips`, `state_abbr` | `silver.xwalk_tract_county`, `metro_deep_dive.geo.tracts_supported_states`, `foundation.tract_features`, `foundation.market_tract_geometry` | Implemented state-level tract backbone coverage summary for national expansion QA. |
| `qa.foundation_null_rates` | one row per dataset-column pair | `foundation.cbsa_features`, `foundation.tract_features` | Implemented null-rate QA table. |

## Scoring

| Table | Grain | Direct parents | Notes |
| --- | --- | --- | --- |
| `scoring.tract_scores` | `market_key`, `tract_geoid` | `foundation.tract_features`, scoring parameters | Implemented in first slice. |
| `scoring.cluster_seed_tracts` | `market_key`, `tract_geoid` | `scoring.tract_scores` | Implemented in first slice. |

## Zones

| Table | Grain | Direct parents | Notes |
| --- | --- | --- | --- |
| `zones.zone_input_candidates` | `market_key`, `tract_geoid` | `scoring.tract_scores`, `scoring.cluster_seed_tracts`, tract geometry | Implemented in first slice. |
| `zones.contiguity_zone_components` | `market_key`, `tract_geoid` | `zones.zone_input_candidates` | Implemented in first slice. |
| `zones.contiguity_zone_summary` | `market_key`, `zone_id` | `zones.zone_input_candidates`, `zones.contiguity_zone_components` | Implemented in first slice. |
| `zones.contiguity_zone_geometries` | `market_key`, `zone_id` | `zones.zone_input_candidates`, `zones.contiguity_zone_components` | Implemented in first slice, stored with `geom_wkt`. |
| `zones.cluster_assignments` | `market_key`, `tract_geoid` | `zones.zone_input_candidates` | Implemented in first slice. |
| `zones.cluster_zone_summary` | `market_key`, `cluster_id` | `zones.zone_input_candidates`, `zones.cluster_assignments` | Implemented in first slice. |
| `zones.cluster_zone_geometries` | `market_key`, `cluster_id` | `zones.zone_input_candidates`, `zones.cluster_assignments` | Implemented in first slice, stored with `geom_wkt`. |

## Parcel Transition Decision

| Table / artifact | Grain | Direct parents | Notes |
| --- | --- | --- | --- |
| Existing DuckDB parcel tables | county parcel grain | manual county parcel workflow | Reuse for tabular parcel serving where possible. |
| Existing parcel analysis `.RDS` artifacts | county parcel geometry grain | manual county parcel workflow | Remain the geometry-bearing source in first slice. |
| `parcel.parcels_canonical` | `parcel_uid` | `rof_parcel.parcel_tabular_clean`, `ref.market_county_membership` | Implemented market-aware canonical parcel table without geometry. |
| `parcel.parcel_join_qa` | `market_key`, `county_geoid` | `parcel.parcel_lineage` | Implemented compatibility county-grain parcel geometry QA projection. |
| `parcel.parcel_lineage` | `market_key`, `county_geoid` | `ref.market_county_membership`, `parcel_geometry_join_qa_county_summary.rds`, `rof_parcel.parcel_county_load_log`, `parcel.parcels_canonical` | Implemented primary county-grain parcel lineage table. |
| `parcel.retail_parcels` | `parcel_uid` | `parcel.parcels_canonical` | Implemented compatibility retail-only subset without geometry. |
| `qa.parcel_validation_results` | one row per QA check | `parcel.*` tables | Implemented parcel-layer QA summary. |
| `qa.parcel_unmapped_use_codes` | `land_use_code` | `parcel.parcels_canonical`, `ref.land_use_mapping` | Implemented unresolved parcel use-code coverage table. |
| tract GEOID derivation from block GEOID | derived key rule | Census GEOID standard | Use first 11 characters of a 15-character block GEOID where block GEOIDs are present. |
