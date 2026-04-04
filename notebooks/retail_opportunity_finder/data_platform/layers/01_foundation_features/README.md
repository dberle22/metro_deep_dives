# Layer 01 - Foundation Features

This layer owns reusable tract- and metro-level analytical features consumed by scoring and downstream notebook builds.

## Current State
- Existing feature queries already live in `sql/features/`.
- Section 02 and Section 03 consume these features directly.

## Transition Goal
- Treat feature products as upstream data platform assets, not notebook-owned intermediates.
- Keep SQL-based feature generation reusable across markets.

## Current Products
- `foundation.cbsa_features`
- `foundation.tract_features`
- `foundation.market_tract_geometry`
- `foundation.market_county_geometry`
- `foundation.market_cbsa_geometry`
- optional context tables when market context artifacts exist:
  - `foundation.context_cbsa_boundary`
  - `foundation.context_county_boundary`
  - `foundation.context_places`
  - `foundation.context_major_roads`
  - `foundation.context_water`
- QA outputs:
  - `qa.foundation_validation_results`
  - `qa.foundation_null_rates`

## Notes
- `tract_features` are rendered dynamically for the active market/year from the existing SQL file before publication.
- Section 02 now has a dedicated input module that prefers these foundation tables and falls back to legacy SQL if they are missing.
