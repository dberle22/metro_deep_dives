-- Test script for Layer 05 Market Serving Prep
-- Run this after executing Layer 05 processing

-- Check row counts for each table
SELECT 'serving.retail_parcel_tract_assignment' AS table_name, COUNT(*) AS row_count FROM serving.retail_parcel_tract_assignment
UNION ALL
SELECT 'serving.retail_intensity_by_tract' AS table_name, COUNT(*) AS row_count FROM serving.retail_intensity_by_tract
UNION ALL
SELECT 'serving.parcel_zone_overlay' AS table_name, COUNT(*) AS row_count FROM serving.parcel_zone_overlay
UNION ALL
SELECT 'serving.parcel_shortlist' AS table_name, COUNT(*) AS row_count FROM serving.parcel_shortlist
UNION ALL
SELECT 'serving.parcel_shortlist_summary' AS table_name, COUNT(*) AS row_count FROM serving.parcel_shortlist_summary
UNION ALL
SELECT 'qa.market_serving_validation_results' AS table_name, COUNT(*) AS row_count FROM qa.market_serving_validation_results;

-- Check for validation failures
SELECT check_name, severity, pass, details
FROM qa.market_serving_validation_results
WHERE pass = FALSE
ORDER BY severity, check_name;

-- Sample data checks
-- Check retail_parcel_tract_assignment has expected columns
DESCRIBE serving.retail_parcel_tract_assignment;

-- Check tract assignments are complete
SELECT
  COUNT(*) AS total_assignments,
  SUM(CASE WHEN assignment_status = 'assigned' THEN 1 ELSE 0 END) AS assigned_count,
  SUM(CASE WHEN assignment_status != 'assigned' THEN 1 ELSE 0 END) AS unassigned_count,
  ROUND(100.0 * SUM(CASE WHEN assignment_status = 'assigned' THEN 1 ELSE 0 END) / COUNT(*), 2) AS assignment_rate_pct
FROM serving.retail_parcel_tract_assignment;

-- Check retail intensity by tract
SELECT
  COUNT(*) AS total_tracts,
  AVG(retail_parcel_count) AS avg_retail_parcels_per_tract,
  AVG(retail_area_density) AS avg_retail_density,
  MAX(retail_parcel_count) AS max_retail_parcels_in_tract
FROM serving.retail_intensity_by_tract;

-- Check parcel shortlist distribution
SELECT
  zone_system,
  zone_id,
  shortlisted_parcels,
  top_shortlist_score
FROM serving.parcel_shortlist_summary
ORDER BY top_shortlist_score DESC
LIMIT 10;

-- Check market distribution across tables
SELECT
  'retail_parcel_tract_assignment' AS table_name,
  market_key,
  COUNT(*) AS row_count
FROM serving.retail_parcel_tract_assignment
GROUP BY market_key
UNION ALL
SELECT
  'retail_intensity_by_tract' AS table_name,
  market_key,
  COUNT(*) AS row_count
FROM serving.retail_intensity_by_tract
GROUP BY market_key
UNION ALL
SELECT
  'parcel_zone_overlay' AS table_name,
  market_key,
  COUNT(*) AS row_count
FROM serving.parcel_zone_overlay
GROUP BY market_key
ORDER BY table_name, row_count DESC;