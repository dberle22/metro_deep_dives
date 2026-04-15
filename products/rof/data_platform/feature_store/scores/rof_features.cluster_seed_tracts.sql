-- rof_features.cluster_seed_tracts.sql
-- Purpose: Build model-specific tract cluster seeds from rof_features.tract_models.
-- Grain: one row per cbsa_code, tract_geoid, model_name for retained seed tracts.
-- Notes:
-- - This keeps all models in one long table instead of one seed table per model.
-- - Seed selection is applied independently within each cbsa_code and model_name.
-- - The current seed rule retains the top 25% of eligible tracts per model.

CREATE OR REPLACE TABLE rof_features.cluster_seed_tracts AS

WITH model_long AS (
  SELECT
    cbsa_code,
    tract_geoid,
    'balanced' AS model_name,
    score_balanced AS model_score,
    rank_balanced_cbsa AS model_rank_cbsa,
    rank_balanced_national AS model_rank_national,
    eligible_flag
  FROM rof_features.tract_models

  UNION ALL

  SELECT
    cbsa_code,
    tract_geoid,
    'growth' AS model_name,
    score_growth AS model_score,
    rank_growth_cbsa AS model_rank_cbsa,
    rank_growth_national AS model_rank_national,
    eligible_flag
  FROM rof_features.tract_models

  UNION ALL

  SELECT
    cbsa_code,
    tract_geoid,
    'value' AS model_name,
    score_value AS model_score,
    rank_value_cbsa AS model_rank_cbsa,
    rank_value_national AS model_rank_national,
    eligible_flag
  FROM rof_features.tract_models

  UNION ALL

  SELECT
    cbsa_code,
    tract_geoid,
    'corridor' AS model_name,
    score_corridor AS model_score,
    rank_corridor_cbsa AS model_rank_cbsa,
    rank_corridor_national AS model_rank_national,
    eligible_flag
  FROM rof_features.tract_models
),

eligible_models AS (
  SELECT
    cbsa_code,
    tract_geoid,
    model_name,
    model_score,
    model_rank_cbsa,
    model_rank_national,
    eligible_flag
  FROM model_long
  WHERE eligible_flag = 1
),

seed_inputs AS (
  SELECT
    cbsa_code,
    tract_geoid,
    model_name,
    model_score,
    model_rank_cbsa,
    model_rank_national,
    eligible_flag,
    0.25 AS cluster_top_share,
    CEIL(COUNT(*) OVER (PARTITION BY cbsa_code, model_name) * 0.25) AS cluster_cutoff_n,
    ROW_NUMBER() OVER (
      PARTITION BY cbsa_code, model_name
      ORDER BY model_score DESC, tract_geoid
    ) AS cluster_seed_rank
  FROM eligible_models
)

SELECT
  cbsa_code,
  tract_geoid,
  model_name,
  model_score,
  model_rank_cbsa,
  model_rank_national,
  cluster_seed_rank,
  cluster_top_share,
  cluster_cutoff_n,
  eligible_flag,
  CASE
    WHEN cluster_seed_rank <= cluster_cutoff_n THEN 1 ELSE 0
  END AS is_cluster_seed
FROM seed_inputs
WHERE cluster_seed_rank <= cluster_cutoff_n
ORDER BY cbsa_code, model_name, cluster_seed_rank, tract_geoid;
