-- serving.parcel_shortlist.sql
-- Purpose: Score and rank retail parcels within zones using a composite scoring model
-- Grain: one row per market_key, zone_system, parcel_uid
-- Notes: Uses tract assignment, tract retail intensity, parcel canonical attributes, and zone summaries.

CREATE OR REPLACE TABLE serving.parcel_shortlist AS 

WITH parcel_assignment AS (
  SELECT *
  FROM serving.retail_parcel_tract_assignment
),
retail_intensity_by_tract AS (
  SELECT *
  FROM serving.retail_intensity_by_tract
),
zone_assignments AS (
  SELECT
    c.market_key,
    c.tract_geoid,
    s.zone_id,
    s.zone_label,
    s.zone_order,
    s.mean_tract_score,
    'contiguity' AS zone_system
  FROM zones.contiguity_zone_components c
  LEFT JOIN zones.contiguity_zone_summary s
    ON c.market_key = s.market_key
    AND c.zone_component_id = s.zone_component_id
  UNION ALL
  SELECT
    a.market_key,
    a.tract_geoid,
    a.cluster_id AS zone_id,
    a.cluster_label AS zone_label,
    a.cluster_order AS zone_order,
    s.mean_tract_score,
    'cluster' AS zone_system
  FROM zones.cluster_assignments a
  LEFT JOIN zones.cluster_zone_summary s
    ON a.market_key = s.market_key
    AND a.cluster_id = s.cluster_id
),
zone_summaries AS (
  SELECT
    market_key,
    zone_system,
    zone_id,
    zone_label,
    zone_order,
    mean_tract_score,
    COALESCE(
      percent_rank() OVER (PARTITION BY market_key ORDER BY mean_tract_score),
      0.5
    ) AS zone_quality_score
  FROM (
    SELECT
      market_key,
      'contiguity' AS zone_system,
      zone_id,
      zone_label,
      zone_order,
      mean_tract_score
    FROM zones.contiguity_zone_summary
    UNION ALL
    SELECT
      market_key,
      'cluster' AS zone_system,
      cluster_id AS zone_id,
      cluster_label AS zone_label,
      cluster_order AS zone_order,
      mean_tract_score
    FROM zones.cluster_zone_summary
  ) zs
),
retail_attrs AS (
  SELECT
    pa.market_key,
    pa.cbsa_code,
    pa.parcel_uid,
    pa.parcel_id,
    pa.tract_geoid,
    pa.county_geoid,
    pa.county_fips,
    pa.county_name,
    pa.state_abbr,
    pa.land_use_code,
    pc.land_use_description AS use_code_definition,
    pc.land_use_category AS use_code_type,
    pa.retail_subtype,
    pc.review_note,
    pc.owner_name,
    pc.owner_addr,
    pc.site_addr,
    CAST(NULL AS DOUBLE) AS parcel_area_sqmi,
    pa.just_value,
    COALESCE(pa.total_value, pa.land_value) AS assessed_value,
    pa.last_sale_date,
    pa.last_sale_price
  FROM parcel_assignment pa
  LEFT JOIN parcel.parcels_canonical pc
    ON pa.parcel_uid = pc.parcel_uid
  WHERE pa.assignment_status = 'assigned'
    AND pa.tract_geoid IS NOT NULL
),
candidate_rows AS (
  SELECT
    ra.market_key,
    ra.cbsa_code,
    'rof_v1' AS model_id,
    'locked_defaults_upstream_sprint7' AS model_version,
    za.zone_system,
    za.zone_id,
    za.zone_label,
    za.zone_order,
    ra.parcel_uid,
    ra.parcel_id,
    ra.tract_geoid,
    ra.county_geoid,
    ra.county_fips,
    ra.county_name,
    ra.state_abbr,
    ra.land_use_code,
    ra.use_code_definition,
    ra.use_code_type,
    ra.retail_subtype,
    ra.review_note,
    ra.owner_name,
    ra.owner_addr,
    ra.site_addr,
    ra.parcel_area_sqmi,
    ra.just_value,
    ra.assessed_value,
    ra.last_sale_date,
    ra.last_sale_price,
    ri.pctl_tract_retail_parcel_count,
    ri.pctl_tract_retail_area_density,
    ri.local_retail_context_score,
    za.mean_tract_score,
    zs.zone_quality_score
  FROM retail_attrs ra
  INNER JOIN zone_assignments za
    ON ra.market_key = za.market_key
    AND ra.tract_geoid = za.tract_geoid
  LEFT JOIN retail_intensity_by_tract ri
    ON ra.market_key = ri.market_key
    AND ra.tract_geoid = ri.tract_geoid
  LEFT JOIN zone_summaries zs
    ON za.market_key = zs.market_key
    AND za.zone_system = zs.zone_system
    AND za.zone_id = zs.zone_id
),
parcel_metrics_base AS (
  SELECT DISTINCT
    market_key,
    parcel_uid,
    parcel_area_sqmi,
    just_value,
    assessed_value,
    last_sale_date,
    CASE
      WHEN just_value > 0 THEN just_value
      ELSE NULL
    END AS just_value_clean,
    CASE
      WHEN assessed_value > 0 THEN assessed_value
      ELSE NULL
    END AS assessed_value_clean,
    CASE
      WHEN parcel_area_sqmi IS NOT NULL AND parcel_area_sqmi * 27878400 >= 1000
      THEN parcel_area_sqmi * 27878400
      ELSE NULL
    END AS parcel_area_sqft_clean,
    CASE
      WHEN last_sale_date IS NOT NULL
      THEN date_diff('day', CAST(last_sale_date AS DATE), CURRENT_DATE)
      ELSE NULL
    END AS sale_recency_days
  FROM candidate_rows
),
parcel_metrics_psf AS (
  SELECT
    *,
    CASE
      WHEN just_value_clean IS NOT NULL
        AND parcel_area_sqft_clean IS NOT NULL
        AND parcel_area_sqft_clean > 0
      THEN just_value_clean / parcel_area_sqft_clean
      ELSE NULL
    END AS assessed_value_psf
  FROM parcel_metrics_base
),
parcel_psf_bounds AS (
  SELECT
    market_key,
    quantile_cont(assessed_value_psf, 0.05) AS psf_q05,
    quantile_cont(assessed_value_psf, 0.95) AS psf_q95
  FROM parcel_metrics_psf
  WHERE assessed_value_psf IS NOT NULL
  GROUP BY market_key
),
parcel_metrics AS (
  SELECT
    p.market_key,
    p.parcel_uid,
    p.parcel_area_sqmi,
    p.sale_recency_days,
    CASE
      WHEN p.assessed_value_psf IS NULL THEN NULL
      WHEN b.psf_q05 IS NULL OR b.psf_q95 IS NULL THEN p.assessed_value_psf
      WHEN p.assessed_value_psf < b.psf_q05 THEN b.psf_q05
      WHEN p.assessed_value_psf > b.psf_q95 THEN b.psf_q95
      ELSE p.assessed_value_psf
    END AS assessed_value_psf_winsorized
  FROM parcel_metrics_psf p
  LEFT JOIN parcel_psf_bounds b
    ON p.market_key = b.market_key
),
parcel_area_ranks AS (
  SELECT
    market_key,
    parcel_uid,
    percent_rank() OVER (PARTITION BY market_key ORDER BY parcel_area_sqmi) AS pctl_parcel_area
  FROM parcel_metrics
  WHERE parcel_area_sqmi IS NOT NULL
),
parcel_value_ranks AS (
  SELECT
    market_key,
    parcel_uid,
    percent_rank() OVER (PARTITION BY market_key ORDER BY assessed_value_psf_winsorized) AS pctl_assessed_value_psf
  FROM parcel_metrics
  WHERE assessed_value_psf_winsorized IS NOT NULL
),
parcel_sale_ranks AS (
  SELECT
    market_key,
    parcel_uid,
    percent_rank() OVER (PARTITION BY market_key ORDER BY sale_recency_days DESC) AS pctl_sale_recency
  FROM parcel_metrics
  WHERE sale_recency_days IS NOT NULL
),
scored_rows AS (
  SELECT
    c.market_key,
    c.cbsa_code,
    c.model_id,
    c.model_version,
    c.zone_system,
    c.zone_id,
    c.zone_label,
    c.parcel_uid,
    c.parcel_id,
    c.tract_geoid,
    c.county_geoid,
    c.county_fips,
    c.county_name,
    c.state_abbr,
    c.land_use_code,
    c.use_code_definition,
    c.use_code_type,
    c.retail_subtype,
    c.review_note,
    c.owner_name,
    c.owner_addr,
    c.site_addr,
    c.parcel_area_sqmi,
    c.just_value,
    c.assessed_value,
    c.last_sale_date,
    c.last_sale_price,
    c.pctl_tract_retail_parcel_count,
    c.pctl_tract_retail_area_density,
    c.local_retail_context_score,
    c.mean_tract_score,
    c.zone_quality_score,
    COALESCE(a.pctl_parcel_area, 0.5) AS pctl_parcel_area,
    COALESCE(v.pctl_assessed_value_psf, 0.5) AS pctl_assessed_value_psf,
    1 - COALESCE(v.pctl_assessed_value_psf, 0.5) AS inv_pctl_assessed_value_psf,
    COALESCE(s.pctl_sale_recency, 0.5) AS pctl_sale_recency,
    0.4 * COALESCE(a.pctl_parcel_area, 0.5)
      + 0.3 * (1 - COALESCE(v.pctl_assessed_value_psf, 0.5))
      + 0.3 * COALESCE(s.pctl_sale_recency, 0.5) AS parcel_characteristics_score,
    0.50 * COALESCE(c.zone_quality_score, 0.5)
      + 0.25 * COALESCE(c.local_retail_context_score, 0.5)
      + 0.25 * (
        0.4 * COALESCE(a.pctl_parcel_area, 0.5)
        + 0.3 * (1 - COALESCE(v.pctl_assessed_value_psf, 0.5))
        + 0.3 * COALESCE(s.pctl_sale_recency, 0.5)
      ) AS shortlist_score
  FROM candidate_rows c
  LEFT JOIN parcel_area_ranks a
    ON c.market_key = a.market_key
    AND c.parcel_uid = a.parcel_uid
  LEFT JOIN parcel_value_ranks v
    ON c.market_key = v.market_key
    AND c.parcel_uid = v.parcel_uid
  LEFT JOIN parcel_sale_ranks s
    ON c.market_key = s.market_key
    AND c.parcel_uid = s.parcel_uid
)
SELECT
  market_key,
  cbsa_code,
  model_id,
  model_version,
  zone_system,
  zone_id,
  zone_label,
  row_number() OVER (
    PARTITION BY market_key, zone_system
    ORDER BY shortlist_score DESC, zone_quality_score DESC, parcel_uid
  ) AS shortlist_rank_system,
  row_number() OVER (
    PARTITION BY market_key, zone_system, zone_id
    ORDER BY shortlist_score DESC, parcel_uid
  ) AS shortlist_rank_zone,
  parcel_uid,
  parcel_id,
  tract_geoid,
  county_geoid,
  county_fips,
  county_name,
  state_abbr,
  land_use_code,
  use_code_definition,
  use_code_type,
  retail_subtype,
  review_note,
  owner_name,
  owner_addr,
  site_addr,
  parcel_area_sqmi,
  just_value,
  assessed_value,
  last_sale_date,
  last_sale_price,
  pctl_tract_retail_parcel_count,
  pctl_tract_retail_area_density,
  local_retail_context_score,
  mean_tract_score,
  zone_quality_score,
  parcel_characteristics_score,
  shortlist_score
FROM scored_rows
ORDER BY market_key, zone_system, shortlist_rank_system;
