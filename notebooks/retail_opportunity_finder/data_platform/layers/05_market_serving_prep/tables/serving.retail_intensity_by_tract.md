# `serving.retail_intensity_by_tract`

- Grain: one row per `market_key`, `tract_geoid`
- Published by: `serving.retail_intensity_by_tract.sql`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.retail_intensity_by_tract.sql`
- Status: implemented as SQL-first multi-market publication

## Table role

- Quantifies retail development intensity at the census tract level
- Provides local retail context scores for parcel evaluation
- Supports zone-based analysis by establishing baseline retail density metrics

## Key columns

- `market_key`, `cbsa_code`: Market identification
- `tract_geoid`: Census tract identifier
- `tract_land_area_sqmi`: Total tract land area
- `retail_parcel_count`: Number of retail parcels in tract
- `retail_area`: Total retail parcel area (square miles)
- `retail_area_density`: Retail area as percentage of tract land area
- Percentile rankings: `pctl_tract_retail_parcel_count`, `pctl_tract_retail_area_density`
- `local_retail_context_score`: Composite score (50% parcel count + 50% area density percentiles)

## Calculation logic

1. **Parcel aggregation**: Count distinct retail parcels and sum their areas per tract
2. **Density calculation**: Retail area divided by tract land area
3. **Percentile ranking**: Market-wide percentile ranks for cross-tract comparison
4. **Context scoring**: Equal-weighted combination of parcel count and density percentiles

## Dependencies

- `serving.retail_parcel_tract_assignment`: Parcel-to-tract assignments
- `foundation.market_tract_geometry`: Tract boundaries and areas

## Business context

- Higher `local_retail_context_score` indicates tracts with more intensive retail development
- Used in parcel shortlisting to identify parcels in areas of varying retail saturation
- Supports analysis of retail opportunity vs. retail saturation scenarios