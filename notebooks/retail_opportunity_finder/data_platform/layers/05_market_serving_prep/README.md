# Layer 05 - Market Serving Prep

This layer will publish notebook-ready parcel-zone products after parcel standardization and zone build are upstream.

## This Slice Includes
- upstream tract assignment for retail parcels
- tract-level retail intensity publication
- parcel-zone overlay publication for `cluster` and `contiguity`
- Section 05 consumer handoff support

## Current Outputs
- `serving.retail_parcel_tract_assignment`
- `serving.retail_intensity_by_tract`
- `serving.parcel_zone_overlay`
- `qa.market_serving_validation_results`

## Optimization Design
This layer computes parcel-to-tract assignment once and then inherits zone membership from tract-to-zone assignment tables.

That avoids repeating parcel-to-zone geometry joins in the notebook path and should materially reduce Section 05 execution time.

## Deferred
- full upstream parcel shortlist publication and summary tables
- deeper shortlist model governance
- non-Florida parcel adapter patterns
- optional geometry serving for shortlist/cartography helpers
