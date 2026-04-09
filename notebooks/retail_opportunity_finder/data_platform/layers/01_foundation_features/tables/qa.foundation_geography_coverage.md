# `qa.foundation_geography_coverage`

- Grain: one row per `state_fips`, `state_abbr`
- Published by: `foundation_feature_workflow.R`
- Status: implemented on `2026-04-06`

## Table role

- Surfaces tract backbone coverage by state across the foundation layer and its upstream geography sources.
- Designed to make national-expansion blockers obvious without treating valid non-CBSA tracts as join bugs.

## Key columns

- `tract_universe_rows`: distinct tract rows present in `silver.xwalk_tract_county`
- `tract_feature_rows`: distinct tract rows published into `foundation.tract_features`
- `cbsa_tract_feature_rows`: tract feature rows with a populated `cbsa_code`
- `non_cbsa_tract_feature_rows`: tract feature rows with null or blank `cbsa_code`
- `tract_geometry_source_rows`: distinct tract rows present in `metro_deep_dive.geo.tracts_supported_states`
- `market_tract_geometry_rows`: distinct tract rows present in `foundation.market_tract_geometry`
- `tract_universe_minus_feature_rows`: gap between the tract universe and tract feature publication
- `tract_universe_minus_geometry_source_rows`: gap between the tract universe and the tract geometry source
- `geometry_source_minus_tract_universe_rows`: extra tract geometry rows present upstream but absent from the tract crosswalk universe

## Intended use

- Check tract counts by state during the move from southeastern support tables to a true U.S. backbone.
- Confirm whether feature gaps are coming from the tract universe, the geometry source, or CBSA membership.
- Quantify expected non-CBSA tracts by state instead of flagging them as generic null-key defects.
