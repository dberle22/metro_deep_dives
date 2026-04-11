# `rof_features.tract_models`

- Grain: one row per `cbsa_code`, `tract_geoid`
- Published by: tract-model SQL build
- Managed build asset: `products/rof/data_platform/feature_store/scores/rof_features.tract_models.sql`
- Status: implemented as a table-owned SQL asset on `2026-04-10`

## Table role

- This table is the canonical wide tract scoring output for the ROF tract-model framework.
- It is built directly from `rof_features.tract_features` using the reference contract in `products/rof/docs/rof_tract_models_reference.md`.
- The table keeps the consumer-facing tract model outputs together in one row: raw features, gate flags, model scores, and ranks.
- The design intentionally keeps the deeper scoring internals in `rof_features.tract_model_audit` so this table can stay relatively clean for downstream consumers.

## Current design snapshot

- Scoring is computed within each `cbsa_code`, so z-score standardization and rank behavior remain market-relative.
- Missing feature values are median-imputed within each `cbsa_code` before z-score computation, matching the current tract scoring approach as closely as possible in SQL.
- The table publishes four model variants:
  - `balanced`
  - `growth`
  - `value`
  - `corridor`
- National ranks are limited to tracts with a populated `cbsa_code`, consistent with the reference note that these are metro-only ranks.

## Output contract highlights

- Identifiers:
  - `cbsa_code`
  - `tract_geoid`
- Raw features:
  - `pop_growth_3yr`
  - `permits_per_1k_3yr`
  - `density`
  - `price_proxy`
  - `commute_intensity`
  - `median_household_income`
- Gates:
  - `growth_gate_flag`
  - `price_gate_flag`
  - `density_gate_flag`
  - `eligible_flag`
- Model scores:
  - `score_balanced`
  - `score_growth`
  - `score_value`
  - `score_corridor`
- Ranks:
  - `rank_balanced_cbsa`
  - `rank_balanced_national`
  - `rank_growth_cbsa`
  - `rank_growth_national`
  - `rank_value_cbsa`
  - `rank_value_national`
  - `rank_corridor_cbsa`
  - `rank_corridor_national`

## Naming and compatibility notes

- Feature naming follows the tract-model reference output contract rather than the legacy tract-feature column names:
  - `units_per_1k_3yr` is surfaced as `permits_per_1k_3yr`
  - `pop_density` is surfaced as `density`
  - `commute_intensity_b` is surfaced as `commute_intensity`
  - `median_hh_income` is surfaced as `median_household_income`
- `price_proxy` currently comes from `rof_features.tract_features.price_proxy_pctl`, because that is the currently published tract-level proxy field available in the feature spine.
- This table is intended to replace the core scoring role of the legacy `scoring.tract_scores` asset over time, but it does not preserve the full legacy compatibility payload such as `why_tags`.

## Managed-path notes

- This table establishes the new reference-driven source of truth for tract model scoring in ROF.
- The table is designed to pair with:
  - `rof_features.tract_model_audit` for scoring diagnostics and explainability
  - `rof_features.cluster_seed_tracts` for model-specific seed selection
- The legacy `scoring.tract_scores` and `scoring.cluster_seed_tracts` assets remain in place during transition because downstream zone-build consumers still depend on the older contract.
