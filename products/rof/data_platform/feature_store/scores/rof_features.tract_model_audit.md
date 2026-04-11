# `rof_features.tract_model_audit`

- Grain: one row per `cbsa_code`, `tract_geoid`
- Published by: tract-model SQL build
- Managed build asset: `products/rof/data_platform/feature_store/scores/rof_features.tract_model_audit.sql`
- Status: implemented as a table-owned SQL asset on `2026-04-10`

## Table role

- This table is the diagnostics and explainability companion to `rof_features.tract_models`.
- It is built directly from `rof_features.tract_features` using the same tract-model scoring logic as the canonical model table.
- The table carries the scoring internals that are useful for QA, model review, and debugging without overloading the consumer-facing `tract_models` output.
- The intended usage pattern is:
  - `rof_features.tract_models` for downstream consumption
  - `rof_features.tract_model_audit` for validation, investigation, and interpretability

## Current design snapshot

- Scoring inputs are median-imputed within each `cbsa_code` before standardization.
- The table keeps both raw inputs and scoring inputs so analysts can see where imputation changed the value used by the model.
- Eligibility gates are preserved alongside z-scores, contribution columns, model scores, and ranks so the full tract scoring path can be audited from one table.
- The table computes the same four model variants as `rof_features.tract_models`:
  - `balanced`
  - `growth`
  - `value`
  - `corridor`

## Output contract highlights

- Raw inputs and gate percentiles:
  - `pop_growth_3yr`
  - `permits_per_1k_3yr`
  - `density`
  - `price_proxy`
  - `commute_intensity`
  - `median_household_income`
  - `pop_growth_pctl`
  - `price_proxy_pctl`
  - `density_pctl`
- Imputation diagnostics:
  - `imputed_pop_growth_flag`
  - `imputed_permits_flag`
  - `imputed_density_flag`
  - `imputed_price_flag`
  - `imputed_commute_flag`
  - `imputed_income_flag`
  - `*_scoring` fields for each modeled input
- Standardized values:
  - `z_pop_growth`
  - `z_permits`
  - `z_density`
  - `z_density_inv`
  - `z_price`
  - `z_price_inv`
  - `z_commute`
  - `z_income`
- Gates:
  - `growth_gate_flag`
  - `price_gate_flag`
  - `density_gate_flag`
  - `eligible_flag`
- Model explainability:
  - contribution columns for each model-feature combination
  - model scores for all four models
  - CBSA and national ranks for all four models

## Naming and compatibility notes

- The audit table follows the tract-model output naming convention rather than the older tract-scoring names.
- It is intentionally wider than `rof_features.tract_models` so model explainability and QA can happen without reconstructing internals from upstream logic.
- This table is not intended to preserve legacy notebook-facing fields like `why_tags`; it is a model-audit surface rather than a direct compatibility layer for `scoring.tract_scores`.

## Managed-path notes

- This table should remain tightly aligned with `rof_features.tract_models`; if one model’s weights, gates, or feature definitions change, both assets should be updated together.
- The audit table is the right place for future additions such as:
  - scoring version metadata
  - reference version metadata
  - extra QA-only diagnostics
- This split keeps the model framework cleaner than the legacy single-table `scoring.tract_scores` approach while still preserving visibility into how tracts are being scored.
