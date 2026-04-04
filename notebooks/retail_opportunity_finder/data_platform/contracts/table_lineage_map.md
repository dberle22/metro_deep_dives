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
| `ref.tract_dim` | `tract_geoid` | `silver.xwalk_tract_county` | Implemented reusable tract dimension. |
| `ref.land_use_mapping` | `land_use_code` | `notebooks/retail_opportunity_finder/land_use_code_mapping.csv`, current reviewed Section 05 candidate overlay | Implemented governed land-use mapping table with retail classification fields. |
| `qa.ref_validation_results` | one row per QA check | `ref.*` tables, current Section 05 mapping candidates CSV | Implemented first-pass QA result table for the reference layer. |
| `qa.ref_unmapped_land_use_codes` | `land_use_code` | `ref.land_use_mapping`, current Section 05 mapping candidates CSV | Implemented unresolved land-use mapping coverage table. |

## Foundation

| Table | Grain | Direct parents | Notes |
| --- | --- | --- | --- |
| `foundation.cbsa_features` | `cbsa_code`, `year` | `sql/features/cbsa_features.sql` inputs | Existing query path; upstream publication still pending. |
| `foundation.tract_features` | `market_key`, `tract_geoid`, `year` | `sql/features/tract_features.sql` rendered for active market/year | Implemented first-pass upstream publication. |
| `foundation.market_tract_geometry` | `market_key`, `tract_geoid` | market profile, DuckDB tract geometry sources | Implemented first-pass geometry-serving table with `geom_wkt`. |
| `foundation.market_county_geometry` | `market_key`, `county_geoid` | market profile, DuckDB county geometry sources | Implemented first-pass geometry-serving table with `geom_wkt`. |
| `foundation.market_cbsa_geometry` | `market_key`, `cbsa_code` | market profile, DuckDB CBSA geometry sources | Implemented first-pass geometry-serving table with `geom_wkt`. |
| `qa.foundation_validation_results` | one row per QA check | `foundation.*` tables | Implemented foundation QA result table. |
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
| `parcel.parcel_join_qa` | `market_key`, `county_geoid` | `parcel_geometry_join_qa_county_summary.rds`, `ref.market_county_membership` | Implemented county-grain parcel geometry QA bridge. |
| `parcel.parcel_lineage` | `market_key`, `county_geoid` | `parcel.parcel_join_qa`, `rof_parcel.parcel_county_load_log`, `parcel.parcels_canonical` | Implemented county-grain parcel lineage table. |
| `parcel.retail_parcels` | `parcel_uid` | `parcel.parcels_canonical`, `ref.land_use_mapping` | Implemented upstream retail parcel classification output without geometry. |
| `qa.parcel_validation_results` | one row per QA check | `parcel.*` tables | Implemented parcel-layer QA summary. |
| `qa.parcel_unmapped_use_codes` | `land_use_code` | `parcel.parcels_canonical`, `ref.land_use_mapping` | Implemented unresolved parcel use-code coverage table. |
| tract GEOID derivation from block GEOID | derived key rule | Census GEOID standard | Use first 11 characters of a 15-character block GEOID where block GEOIDs are present. |
