-- Diagnostic query: can Layer 05 rely on normalized tract-prefix matching?
-- Evaluates whether retail parcels can be assigned to tracts using the first 11 digits of census_block_id.

WITH retail_parcels AS (
  SELECT
    market_key,
    cbsa_code,
    parcel_uid,
    census_block_id,
    regexp_replace(COALESCE(CAST(census_block_id AS VARCHAR), ''), '[^0-9]', '', 'g') AS census_block_digits
  FROM parcel.parcels_canonical
  WHERE retail_flag = TRUE
),
block_eval AS (
  SELECT
    rp.market_key,
    rp.cbsa_code,
    rp.parcel_uid,
    rp.census_block_id,
    rp.census_block_digits,
    CASE
      WHEN length(rp.census_block_digits) >= 11 THEN substr(rp.census_block_digits, 1, 11)
      ELSE NULL
    END AS tract_geoid_candidate
  FROM retail_parcels rp
),
tract_match AS (
  SELECT
    be.market_key,
    be.cbsa_code,
    be.parcel_uid,
    be.census_block_id,
    be.census_block_digits,
    be.tract_geoid_candidate,
    CASE WHEN mtg.tract_geoid IS NOT NULL THEN TRUE ELSE FALSE END AS tract_exists
  FROM block_eval be
  LEFT JOIN foundation.market_tract_geometry mtg
    ON be.cbsa_code = mtg.cbsa_code
    AND be.tract_geoid_candidate = mtg.tract_geoid
)
SELECT
  market_key,
  cbsa_code,
  COUNT(*) AS retail_parcels,
  SUM(CASE WHEN census_block_id IS NOT NULL THEN 1 ELSE 0 END) AS parcels_with_block_id,
  SUM(CASE WHEN length(census_block_digits) >= 11 THEN 1 ELSE 0 END) AS parcels_with_11plus_digit_key,
  SUM(CASE WHEN tract_geoid_candidate IS NOT NULL THEN 1 ELSE 0 END) AS parcels_with_tract_prefix,
  SUM(CASE WHEN tract_exists THEN 1 ELSE 0 END) AS parcels_assignable_from_prefix_only,
  SUM(CASE WHEN NOT tract_exists OR tract_exists IS NULL THEN 1 ELSE 0 END) AS parcels_needing_fallback_or_unassigned,
  ROUND(100.0 * SUM(CASE WHEN tract_exists THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_assignable_from_prefix_only
FROM tract_match
GROUP BY market_key, cbsa_code
ORDER BY pct_assignable_from_prefix_only DESC, market_key;

-- Detail query for troubleshooting problem parcels:
--
-- WITH retail_parcels AS (
--   SELECT
--     market_key,
--     cbsa_code,
--     parcel_uid,
--     census_block_id,
--     regexp_replace(COALESCE(CAST(census_block_id AS VARCHAR), ''), '[^0-9]', '', 'g') AS census_block_digits
--   FROM parcel.parcels_canonical
--   WHERE retail_flag = TRUE
-- ),
-- block_eval AS (
--   SELECT
--     rp.*,
--     CASE
--       WHEN length(rp.census_block_digits) >= 11 THEN substr(rp.census_block_digits, 1, 11)
--       ELSE NULL
--     END AS tract_geoid_candidate
--   FROM retail_parcels rp
-- )
-- SELECT
--   be.market_key,
--   be.cbsa_code,
--   be.parcel_uid,
--   be.census_block_id,
--   be.census_block_digits,
--   be.tract_geoid_candidate
-- FROM block_eval be
-- LEFT JOIN foundation.market_tract_geometry mtg
--   ON be.cbsa_code = mtg.cbsa_code
--   AND be.tract_geoid_candidate = mtg.tract_geoid
-- WHERE mtg.tract_geoid IS NULL
-- ORDER BY be.market_key, be.parcel_uid;
