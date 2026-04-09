# Layer 00 - Reference And Membership

This layer publishes source-backed reference tables used across the ROF V2 platform.

## Current Products
- `ref.market_profiles`
- `ref.market_cbsa_membership`
- `ref.market_county_membership`
- `ref.county_dim`
- `ref.tract_dim`
- `ref.land_use_mapping`
- `qa.ref_validation_results`
- `qa.ref_geography_coverage`
- `qa.ref_unmapped_land_use_codes`

## Current Decisions
- We do not publish a standalone `ref.block_tract_crosswalk` in the first pass.
- Preferred rule for Census identifiers:
  - tract GEOID = first 11 characters of block GEOID
  - block GEOID = 15 characters total
- This is sufficient where parcel or related source systems already provide block GEOIDs.

## Notes
- Reference tables are full-refresh and overwrite in place.
- They are geometry-light dimensions and bridges intended to stabilize joins across layers.
- `qa.ref_geography_coverage` now publishes tract counts by state so national backbone progress is visible in the reference layer itself.
- QA outputs are published alongside the reference tables so downstream layers can review join readiness and mapping coverage.
