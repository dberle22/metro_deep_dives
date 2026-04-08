# Layer 05 - Market Serving Prep

This layer publishes notebook-ready parcel-zone products after parcel standardization and zone build are upstream. Now generalized to process all markets with retail parcels.

## This Slice Includes
- multi-market tract assignment for retail parcels
- tract-level retail intensity publication across all markets
- parcel-zone overlay publication for `cluster` and `contiguity` across all markets
- Section 05 consumer handoff support for all markets

## Current Outputs
- `serving.retail_parcel_tract_assignment` - Multi-market parcel-to-tract assignments
- `serving.retail_intensity_by_tract` - Multi-market tract retail density metrics
- `serving.parcel_zone_overlay` - Multi-market zone-level retail aggregation
- `serving.parcel_shortlist` - Multi-market prioritized parcel shortlists
- `serving.parcel_shortlist_summary` - Multi-market zone shortlist summaries
- `qa.market_serving_validation_results` - Multi-market QA validation results

## Architecture Changes

### File Structure
Following Layer 01-04 patterns, restructured with individual table files:
```
tables/
├── serving.retail_parcel_tract_assignment.R + .md
├── serving.retail_intensity_by_tract.sql/.R + .md
├── serving.parcel_zone_overlay.sql/.R + .md
├── serving.parcel_shortlist.sql/.R + .md
├── serving.parcel_shortlist_summary.R + .md
└── qa.market_serving_validation_results.R + .md
```

### Multi-Market Processing
- `build_market_serving_layer_publications()`: Processes all markets with retail parcels
- Each table now includes `market_key` and `cbsa_code` columns
- Maintains same data processing logic but scales across markets
- QA validation aggregated across all processed markets

## Execution Order

Run Layer 05 tables in this order:

1. `serving.retail_parcel_tract_assignment`
   Uses `parcel.parcels_canonical`, `parcel.parcel_join_qa`, county parcel geometry RDS files, and `foundation.market_tract_geometry`.
2. `serving.retail_intensity_by_tract`
   Uses `serving.retail_parcel_tract_assignment` and `foundation.market_tract_geometry`.
3. `serving.parcel_zone_overlay`
   Uses `serving.retail_intensity_by_tract` plus Layer 03 zone assignment and summary tables.
4. `serving.parcel_shortlist`
   Uses `serving.retail_parcel_tract_assignment`, `serving.retail_intensity_by_tract`, `parcel.parcels_canonical`, and Layer 03 zone tables.
5. `serving.parcel_shortlist_summary`
   Uses `serving.parcel_shortlist`.
6. `qa.market_serving_validation_results`
   Uses all Layer 05 serving outputs after the publish.

In practice, the dependency chain is:

`retail_parcel_tract_assignment -> retail_intensity_by_tract -> parcel_zone_overlay`

`retail_parcel_tract_assignment -> parcel_shortlist -> parcel_shortlist_summary`

`all outputs -> qa.market_serving_validation_results`

## Diagnostics

- Use [test_retail_parcel_block_assignment_coverage.sql](/Users/danberle/Documents/projects/metro_deep_dive/notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/test_retail_parcel_block_assignment_coverage.sql) to measure whether `serving.retail_parcel_tract_assignment` can rely on normalized tract-prefix matching from `census_block_id`.
- If `pct_assignable_from_prefix_only` is effectively 100% for the markets you care about, the geometry fallback is probably unnecessary.

## Investigation Notes

### Orlando Missing Tracts

Latest normalized-prefix QA check showed:

- `jacksonville_fl`: `99.99%` assignable from prefix only
- `gainesville_fl`: `99.95%` assignable from prefix only
- `orlando_fl`: `92.03%` assignable from prefix only

The Orlando misses are not spread across the whole market. They are concentrated in Lake County (`county_geoid = 12069`):

- Orlando total: `22,210` retail parcels, `1,771` missing under normalized-prefix assignment
- Lake County only: `4,212` retail parcels, `1,771` missing, `42.05%` missing
- Other Orlando counties (`12095`, `12097`, `12117`) were effectively `0%` missing

Current hypothesis:

- Lake County parcel `census_block_id` values still look like tract-prefixed 12-digit keys.
- The missing first-11-digit tract candidates do not exist in:
  - `foundation.market_tract_geometry`
  - `metro_deep_dive.silver.xwalk_tract_county`
  - `metro_deep_dive.geo.tracts_supported_states`
- This suggests a tract-vintage or county-specific source coding mismatch rather than a Layer 05 logic bug.

Lake County missing tract candidates recorded during investigation:

- `12069030105`
- `12069030107`
- `12069030207`
- `12069030502`
- `12069030503`
- `12069030504`
- `12069030902`
- `12069030912`
- `12069030913`
- `12069031000`
- `12069031101`
- `12069031102`
- `12069031204`
- `12069031305`
- `12069031307`
- `12069031310`
- `12069031311`
- `NA` / empty normalized key: `7` parcels

Recommended future deep dive:

- Compare Lake County parcel tract candidates against alternate tract vintages if available.
- Inspect whether parcel source geography is using deprecated or county-specific tract coding.
- If a stable mapping exists, build a county-specific tract crosswalk upstream rather than reintroducing parcel geometry fallback in Layer 05.

## Optimization Design
This layer computes parcel-to-tract assignment once per market and then inherits zone membership from tract-to-zone assignment tables.

That avoids repeating parcel-to-zone geometry joins in the notebook path and should materially reduce Section 05 execution time.

## Deferred
- deeper shortlist model governance
- non-Florida parcel adapter patterns
- optional geometry serving for shortlist/cartography helpers
