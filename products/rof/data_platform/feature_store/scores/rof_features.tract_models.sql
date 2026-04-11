-- rof_features.tract_models.sql
-- Purpose: Build tract model scores from rof_features.tract_features using the
-- reference contract in products/rof/docs/rof_tract_models_reference.md.

CREATE OR REPLACE TABLE rof_features.tract_models AS

WITH source_features AS (
  SELECT
    cbsa_code,
    tract_geoid,
    CAST(pop_growth_3yr AS DOUBLE) AS pop_growth_3yr,
    CAST(units_per_1k_3yr AS DOUBLE) AS permits_per_1k_3yr,
    CAST(pop_density AS DOUBLE) AS density,
    CAST(price_proxy_pctl AS DOUBLE) AS price_proxy,
    CAST(commute_intensity_b AS DOUBLE) AS commute_intensity,
    CAST(median_hh_income AS DOUBLE) AS median_household_income,
    CAST(pop_growth_pctl AS DOUBLE) AS pop_growth_pctl,
    CAST(price_proxy_pctl AS DOUBLE) AS price_proxy_pctl,
    CAST(density_pctl AS DOUBLE) AS density_pctl
  FROM rof_features.tract_features
),

imputed AS (
  SELECT
    cbsa_code,
    tract_geoid,
    pop_growth_3yr,
    permits_per_1k_3yr,
    density,
    price_proxy,
    commute_intensity,
    median_household_income,
    pop_growth_pctl,
    price_proxy_pctl,
    density_pctl,
    COALESCE(
      pop_growth_3yr,
      MEDIAN(pop_growth_3yr) OVER (PARTITION BY cbsa_code)
    ) AS pop_growth_scoring,
    COALESCE(
      permits_per_1k_3yr,
      MEDIAN(permits_per_1k_3yr) OVER (PARTITION BY cbsa_code)
    ) AS permits_scoring,
    COALESCE(
      density,
      MEDIAN(density) OVER (PARTITION BY cbsa_code)
    ) AS density_scoring,
    COALESCE(
      price_proxy,
      MEDIAN(price_proxy) OVER (PARTITION BY cbsa_code)
    ) AS price_scoring,
    COALESCE(
      commute_intensity,
      MEDIAN(commute_intensity) OVER (PARTITION BY cbsa_code)
    ) AS commute_scoring,
    COALESCE(
      median_household_income,
      MEDIAN(median_household_income) OVER (PARTITION BY cbsa_code)
    ) AS income_scoring
  FROM source_features
),

zscores AS (
  SELECT
    cbsa_code,
    tract_geoid,
    pop_growth_3yr,
    permits_per_1k_3yr,
    density,
    price_proxy,
    commute_intensity,
    median_household_income,
    pop_growth_pctl,
    price_proxy_pctl,
    density_pctl,
    CASE
      WHEN COALESCE(STDDEV_SAMP(pop_growth_scoring) OVER (PARTITION BY cbsa_code), 0) = 0 THEN 0.0
      ELSE (
        pop_growth_scoring - AVG(pop_growth_scoring) OVER (PARTITION BY cbsa_code)
      ) / NULLIF(STDDEV_SAMP(pop_growth_scoring) OVER (PARTITION BY cbsa_code), 0)
    END AS z_pop_growth,
    CASE
      WHEN COALESCE(STDDEV_SAMP(permits_scoring) OVER (PARTITION BY cbsa_code), 0) = 0 THEN 0.0
      ELSE (
        permits_scoring - AVG(permits_scoring) OVER (PARTITION BY cbsa_code)
      ) / NULLIF(STDDEV_SAMP(permits_scoring) OVER (PARTITION BY cbsa_code), 0)
    END AS z_permits,
    CASE
      WHEN COALESCE(STDDEV_SAMP(density_scoring) OVER (PARTITION BY cbsa_code), 0) = 0 THEN 0.0
      ELSE (
        density_scoring - AVG(density_scoring) OVER (PARTITION BY cbsa_code)
      ) / NULLIF(STDDEV_SAMP(density_scoring) OVER (PARTITION BY cbsa_code), 0)
    END AS z_density,
    CASE
      WHEN COALESCE(STDDEV_SAMP(price_scoring) OVER (PARTITION BY cbsa_code), 0) = 0 THEN 0.0
      ELSE (
        price_scoring - AVG(price_scoring) OVER (PARTITION BY cbsa_code)
      ) / NULLIF(STDDEV_SAMP(price_scoring) OVER (PARTITION BY cbsa_code), 0)
    END AS z_price,
    CASE
      WHEN COALESCE(STDDEV_SAMP(commute_scoring) OVER (PARTITION BY cbsa_code), 0) = 0 THEN 0.0
      ELSE (
        commute_scoring - AVG(commute_scoring) OVER (PARTITION BY cbsa_code)
      ) / NULLIF(STDDEV_SAMP(commute_scoring) OVER (PARTITION BY cbsa_code), 0)
    END AS z_commute,
    CASE
      WHEN COALESCE(STDDEV_SAMP(income_scoring) OVER (PARTITION BY cbsa_code), 0) = 0 THEN 0.0
      ELSE (
        income_scoring - AVG(income_scoring) OVER (PARTITION BY cbsa_code)
      ) / NULLIF(STDDEV_SAMP(income_scoring) OVER (PARTITION BY cbsa_code), 0)
    END AS z_income
  FROM imputed
),

gated AS (
  SELECT
    cbsa_code,
    tract_geoid,
    pop_growth_3yr,
    permits_per_1k_3yr,
    density,
    price_proxy,
    commute_intensity,
    median_household_income,
    z_pop_growth,
    z_permits,
    z_density,
    -z_density AS z_density_inv,
    z_price,
    -z_price AS z_price_inv,
    z_commute,
    z_income,
    CASE WHEN pop_growth_pctl >= 0.50 THEN 1 ELSE 0 END AS growth_gate_flag,
    CASE WHEN price_proxy_pctl < 0.70 THEN 1 ELSE 0 END AS price_gate_flag,
    CASE WHEN density_pctl <= 0.70 THEN 1 ELSE 0 END AS density_gate_flag
  FROM zscores
),

scored AS (
  SELECT
    cbsa_code,
    tract_geoid,
    pop_growth_3yr,
    permits_per_1k_3yr,
    density,
    price_proxy,
    commute_intensity,
    median_household_income,
    z_pop_growth,
    z_permits,
    z_density,
    z_density_inv,
    z_price,
    z_price_inv,
    z_commute,
    z_income,
    growth_gate_flag,
    price_gate_flag,
    density_gate_flag,
    CASE
      WHEN growth_gate_flag = 1
        AND price_gate_flag = 1
        AND density_gate_flag = 1
      THEN 1 ELSE 0
    END AS eligible_flag,
    0.35 * z_pop_growth +
      0.25 * z_permits +
      0.15 * z_density_inv +
      0.10 * z_price_inv +
      0.10 * z_income +
      0.05 * z_commute AS score_balanced,
    0.45 * z_pop_growth +
      0.25 * z_permits +
      0.10 * z_income +
      0.10 * z_density_inv +
      0.05 * z_price_inv +
      0.05 * z_commute AS score_growth,
    0.25 * z_pop_growth +
      0.20 * z_permits +
      0.10 * z_density_inv +
      0.30 * z_price_inv +
      0.10 * z_income +
      0.05 * z_commute AS score_value,
    0.30 * z_commute +
      0.25 * z_pop_growth +
      0.15 * z_permits +
      0.10 * z_density_inv +
      0.10 * z_income +
      0.10 * z_price_inv AS score_corridor
  FROM gated
),

ranked AS (
  SELECT
    cbsa_code,
    tract_geoid,
    pop_growth_3yr,
    permits_per_1k_3yr,
    density,
    price_proxy,
    commute_intensity,
    median_household_income,
    z_pop_growth,
    z_permits,
    z_density,
    z_density_inv,
    z_price,
    z_price_inv,
    z_commute,
    z_income,
    growth_gate_flag,
    price_gate_flag,
    density_gate_flag,
    eligible_flag,
    score_balanced,
    score_growth,
    score_value,
    score_corridor,
    ROW_NUMBER() OVER (
      PARTITION BY cbsa_code
      ORDER BY score_balanced DESC, tract_geoid
    ) AS rank_balanced_cbsa,
    CASE
      WHEN cbsa_code IS NOT NULL AND cbsa_code <> '' THEN
        ROW_NUMBER() OVER (
          ORDER BY score_balanced DESC, cbsa_code, tract_geoid
        )
      ELSE NULL
    END AS rank_balanced_national,
    ROW_NUMBER() OVER (
      PARTITION BY cbsa_code
      ORDER BY score_growth DESC, tract_geoid
    ) AS rank_growth_cbsa,
    CASE
      WHEN cbsa_code IS NOT NULL AND cbsa_code <> '' THEN
        ROW_NUMBER() OVER (
          ORDER BY score_growth DESC, cbsa_code, tract_geoid
        )
      ELSE NULL
    END AS rank_growth_national,
    ROW_NUMBER() OVER (
      PARTITION BY cbsa_code
      ORDER BY score_value DESC, tract_geoid
    ) AS rank_value_cbsa,
    CASE
      WHEN cbsa_code IS NOT NULL AND cbsa_code <> '' THEN
        ROW_NUMBER() OVER (
          ORDER BY score_value DESC, cbsa_code, tract_geoid
        )
      ELSE NULL
    END AS rank_value_national,
    ROW_NUMBER() OVER (
      PARTITION BY cbsa_code
      ORDER BY score_corridor DESC, tract_geoid
    ) AS rank_corridor_cbsa,
    CASE
      WHEN cbsa_code IS NOT NULL AND cbsa_code <> '' THEN
        ROW_NUMBER() OVER (
          ORDER BY score_corridor DESC, cbsa_code, tract_geoid
        )
      ELSE NULL
    END AS rank_corridor_national
  FROM scored
)

SELECT
  cbsa_code,
  tract_geoid,
  pop_growth_3yr,
  permits_per_1k_3yr,
  density,
  price_proxy,
  commute_intensity,
  median_household_income,
  z_pop_growth,
  z_permits,
  z_density,
  z_density_inv,
  z_price,
  z_price_inv,
  z_commute,
  z_income,
  growth_gate_flag,
  price_gate_flag,
  density_gate_flag,
  eligible_flag,
  score_balanced,
  score_growth,
  score_value,
  score_corridor,
  rank_balanced_cbsa,
  rank_balanced_national,
  rank_growth_cbsa,
  rank_growth_national,
  rank_value_cbsa,
  rank_value_national,
  rank_corridor_cbsa,
  rank_corridor_national
FROM ranked
ORDER BY cbsa_code, tract_geoid;
