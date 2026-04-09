# `serving.retail_parcel_tract_assignment`

- Grain: one row per `market_key`, `parcel_uid`
- Published by: `serving.retail_parcel_tract_assignment.sql`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.retail_parcel_tract_assignment.sql`
- Status: proposed for multi-market generalization

## Table role

- Assigns retail parcels to census tracts using validated tract-prefix matching from `census_block_id`
- Provides the foundation for tract-level retail intensity calculations and zone-based parcel analysis
- Supports downstream retail opportunity analysis by establishing parcel-to-tract relationships

## Key columns

- `market_key`, `cbsa_code`: Market identification
- `parcel_uid`: Unique parcel identifier across county sources
- `tract_geoid`: Assigned census tract (11-digit FIPS code)
- `assignment_method`: How the tract was assigned (`normalized_tract_prefix` or `unassigned`)
- `assignment_status`: "assigned" or "unassigned"
- Geographic hierarchy: `state_abbr`, `county_geoid`, `county_name`, etc.
- Parcel attributes: `land_use_code`, `parcel_area_sqmi`, `assessed_value`, etc.

## Assignment logic

1. **Primary method**: Normalize `census_block_id` to digits and use the first 11 digits as a tract candidate
2. **Validation**: Keep the candidate only when it exists in `foundation.market_tract_geometry` for the parcel's `cbsa_code`
3. **Status tracking**: Clear indication of assignment success/failure for QA purposes

## Dependencies

- `parcel.parcels_canonical`: Source retail parcel data (filtered to retail_flag = TRUE)
- `foundation.market_tract_geometry`: Tract boundaries for prefix validation

## QA considerations

- Monitor unassigned parcels after normalized tract-prefix assignment
- Validate tract geoid format and existence
- Check for duplicate parcel assignments
