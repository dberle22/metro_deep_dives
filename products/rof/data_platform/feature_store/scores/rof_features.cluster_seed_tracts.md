# `rof_features.cluster_seed_tracts`

- Grain: one row per `cbsa_code`, `tract_geoid`, `model_name`
- Published by: tract-model SQL build
- Managed build asset: `products/rof/data_platform/feature_store/scores/rof_features.cluster_seed_tracts.sql`
- Status: implemented as a table-owned SQL asset on `2026-04-10`

## Table role

- This table publishes the subset of tracts retained as cluster seeds for each tract model.
- It is derived directly from `rof_features.tract_models`.
- Unlike the legacy `scoring.cluster_seed_tracts` table, this design is model-aware and stores multiple models in one long table instead of assuming a single tract score.
- The table is intended to support downstream zone or clustering workflows that may want to choose different tract seed sets for different models.

## Current design snapshot

- Seed selection is performed independently within each `cbsa_code` and `model_name`.
- The current seed rule retains the top `25%` of eligible tracts for each model.
- The table is long rather than wide:
  - one tract can appear multiple times
  - each appearance corresponds to a different `model_name`
- Only tracts with `eligible_flag = 1` are considered for seed selection.

## Output contract highlights

- Identifiers:
  - `cbsa_code`
  - `tract_geoid`
  - `model_name`
- Model selection context:
  - `model_score`
  - `model_rank_cbsa`
  - `model_rank_national`
- Seed selection fields:
  - `cluster_seed_rank`
  - `cluster_top_share`
  - `cluster_cutoff_n`
  - `eligible_flag`
  - `is_cluster_seed`

## Naming and compatibility notes

- `model_name` currently uses the four tract-model variants:
  - `balanced`
  - `growth`
  - `value`
  - `corridor`
- This table differs from the legacy `scoring.cluster_seed_tracts` design in two important ways:
  - it derives from `rof_features.tract_models` rather than `scoring.tract_scores`
  - it supports multiple models in one table through the `model_name` column
- The long-table design should make downstream model switching simpler than publishing separate seed outputs for each model.

## Managed-path notes

- This table is the model-era replacement for the legacy single-score cluster seed selection logic.
- If the seed-share rule changes from `25%`, this table should be updated centrally rather than duplicating logic in downstream consumers.
- Future zone-build work can either:
  - filter this table to one chosen `model_name`, or
  - parameterize downstream workflows to select the desired model at runtime
