# `serving.parcel_zone_overlay`

- Grain: one row per `market_key`, `zone_system`, `zone_id`
- Published by: `serving.parcel_zone_overlay.sql`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.parcel_zone_overlay.sql`
- Status: implemented as SQL-first multi-market publication

## Table role

- Aggregates retail intensity metrics by zone for comparative analysis
- Combines tract-level retail data with zone demographic and quality scores
- Supports zone-based retail opportunity assessment and prioritization

## Key columns

- `market_key`, `cbsa_code`: Market identification
- `zone_system`: "contiguity" or "cluster" zoning approach
- `zone_id`, `zone_label`, `zone_order`: Zone identification and sorting
- `tracts`: Number of tracts in zone
- `total_population`: Zone population
- `zone_area_sq_mi`: Total zone area
- Retail metrics: `retail_parcel_count`, `retail_area`, `retail_area_density`
- `local_retail_context_score`: Average retail context score across zone tracts
- `mean_tract_score`, `zone_quality_score`: Zone quality metrics from Layer 03

## Aggregation logic

1. **Tract-to-zone mapping**: Uses zone assignment tables from Layer 03
2. **Retail metrics**: Sums parcel counts and areas across zone tracts
3. **Density calculation**: Retail area divided by total tract land area in zone
4. **Score averaging**: Mean retail context score across constituent tracts

## Dependencies

- `zones.contiguity_zone_components` / `zones.cluster_assignments`: Zone membership
- `zones.contiguity_zone_summary` / `zones.cluster_zone_summary`: Zone metadata
- `serving.retail_intensity_by_tract`: Tract-level retail metrics

## Business context

- Enables comparison of retail saturation across different market zones
- Supports identification of high-opportunity zones with low retail density
- Provides foundation for zone-based parcel shortlisting and prioritization