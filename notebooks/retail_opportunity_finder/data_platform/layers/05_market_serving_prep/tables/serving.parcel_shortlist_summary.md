# `serving.parcel_shortlist_summary`

- Grain: one row per `market_key`, `zone_system`, `zone_id`
- Published by: `serving.parcel_shortlist_summary.sql`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.parcel_shortlist_summary.sql`
- Status: implemented as SQL-first multi-market publication

## Table role

- Provides zone-level summary statistics for parcel shortlists
- Enables quick assessment of shortlist quality and composition across zones
- Supports comparative analysis of retail opportunity across market zones

## Key columns

- `market_key`, `cbsa_code`: Market identification
- `zone_system`, `zone_id`, `zone_label`: Zone identification
- `shortlisted_parcels`: Total number of parcels in zone shortlist
- `top_shortlist_score`: Highest shortlist score in zone
- `mean_shortlist_score`: Average shortlist score across zone parcels
- `median_parcel_area_sqmi`: Median parcel area in zone shortlist

## Summary metrics

- **Count**: Total parcels meeting shortlist criteria
- **Quality indicators**: Score distribution statistics
- **Size profile**: Median area for development scale assessment

## Dependencies

- `serving.parcel_shortlist`: Source parcel shortlist data

## Business context

- Higher `mean_shortlist_score` indicates zones with stronger overall retail opportunity
- `median_parcel_area_sqmi` helps assess development scale potential
- Supports zone prioritization and resource allocation decisions