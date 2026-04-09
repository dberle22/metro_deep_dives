-- serving.parcel_shortlist_summary.sql
-- Purpose: Summarize parcel shortlist quality statistics by zone
-- Grain: one row per market_key, cbsa_code, zone_system, zone_id
-- Notes: Uses the parcel shortlist table to compute counts and score statistics. Parcel area is currently unavailable in the tabular-only Layer 05 path.

CREATE OR REPLACE TABLE serving.parcel_shortlist_summary AS 

SELECT
  market_key,
  cbsa_code,
  zone_system,
  zone_id,
  zone_label,
  COUNT(DISTINCT parcel_uid) AS shortlisted_parcels,
  MAX(shortlist_score) AS top_shortlist_score,
  AVG(shortlist_score) AS mean_shortlist_score,
  CAST(NULL AS DOUBLE) AS median_parcel_area_sqmi
FROM serving.parcel_shortlist
GROUP BY market_key, cbsa_code, zone_system, zone_id, zone_label
ORDER BY zone_system, zone_id;
