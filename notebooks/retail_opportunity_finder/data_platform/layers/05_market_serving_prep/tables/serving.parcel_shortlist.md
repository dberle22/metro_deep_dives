# `serving.parcel_shortlist`

- Grain: one row per `market_key`, `zone_system`, `parcel_uid`
- Published by: `serving.parcel_shortlist.sql`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/serving.parcel_shortlist.sql`
- Status: proposed for multi-market generalization

## Table role

- Scores and ranks retail parcels within market zones using a composite model
- Provides prioritized shortlists for retail opportunity analysis
- Combines zone quality, local retail context, and parcel characteristics into unified scores

## Key columns

- `market_key`, `cbsa_code`: Market identification
- `model_id`, `model_version`: Scoring model metadata
- `zone_system`, `zone_id`, `zone_label`: Zone context
- `shortlist_rank_system`, `shortlist_rank_zone`: Ranking within system/zone
- `parcel_uid`, `parcel_id`: Parcel identification
- Geographic context: `tract_geoid`, `county_geoid`, `state_abbr`, etc.
- Parcel attributes: `land_use_code`, `parcel_area_sqmi`, `assessed_value`, etc.
- Component scores: `zone_quality_score`, `local_retail_context_score`, `parcel_characteristics_score`
- `shortlist_score`: Final composite score (0-1 scale)

## Scoring model

**Composite formula**: `shortlist_score = 0.50 × zone_quality_score + 0.25 × local_retail_context_score + 0.25 × parcel_characteristics_score`

**Parcel characteristics score**: `0.4 × parcel_area_percentile + 0.3 × (1 - value_psf_percentile) + 0.3 × sale_recency_percentile`

## Ranking logic

1. **System-wide ranking**: Ordered by score, zone quality, area, parcel_uid within each zone system
2. **Zone-specific ranking**: Additional ranking within each zone for targeted analysis
3. **Deterministic ordering**: Tie-breaking by parcel area and UID ensures consistent results

## Dependencies

- `serving.retail_parcel_tract_assignment`: Parcel-to-tract assignments plus parcel-level metrics
- `serving.retail_intensity_by_tract`: Tract retail context scores
- `parcel.parcels_canonical`: Canonical parcel attributes and land-use metadata
- Zone assignment and summary tables from Layer 03

## Business context

- Higher `shortlist_score` indicates parcels with better retail opportunity characteristics
- Supports identification of high-priority development sites
- Enables zone-based prioritization for retail expansion planning
