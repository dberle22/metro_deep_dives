-- Test script for Layer 04 SQL migration
-- Run this after executing build_parcel_standardization_layer.sql

-- Check row counts for each table
SELECT 'parcel.parcels_canonical' AS table_name, COUNT(*) AS row_count FROM parcel.parcels_canonical
UNION ALL
SELECT 'parcel.parcel_lineage' AS table_name, COUNT(*) AS row_count FROM parcel.parcel_lineage
UNION ALL
SELECT 'parcel.parcel_join_qa' AS table_name, COUNT(*) AS row_count FROM parcel.parcel_join_qa
UNION ALL
SELECT 'parcel.retail_parcels' AS table_name, COUNT(*) AS row_count FROM parcel.retail_parcels
UNION ALL
SELECT 'qa.parcel_unmapped_use_codes' AS table_name, COUNT(*) AS row_count FROM qa.parcel_unmapped_use_codes
UNION ALL
SELECT 'qa.parcel_validation_results' AS table_name, COUNT(*) AS row_count FROM qa.parcel_validation_results;

-- Check markets available in parcel.parcels_canonical
SELECT MARKET_KEY, COUNTY_NAME, COUNT(*) AS TOTAL_RECORDS FROM parcel.parcels_canonical GROUP BY MARKET_KEY, COUNTY_NAME;


-- Check for validation failures
SELECT check_name, severity, pass, details
FROM qa.parcel_validation_results
WHERE pass = FALSE
ORDER BY severity, check_name;

-- Sample data checks
-- Check parcels_canonical has expected columns
DESCRIBE parcel.parcels_canonical;

-- Check retail parcels are subset of canonical
SELECT
  (SELECT COUNT(*) FROM parcel.retail_parcels) AS retail_count,
  (SELECT COUNT(*) FROM parcel.parcels_canonical WHERE retail_flag = TRUE) AS canonical_retail_count,
  CASE WHEN (SELECT COUNT(*) FROM parcel.retail_parcels) = (SELECT COUNT(*) FROM parcel.parcels_canonical WHERE retail_flag = TRUE)
       THEN 'PASS: Retail parcels match canonical filter'
       ELSE 'FAIL: Retail parcels do not match canonical filter' END AS validation;

-- Check parcel_uid uniqueness
SELECT
  'parcel_uid_duplicates' AS check,
  COUNT(*) - COUNT(DISTINCT parcel_uid) AS duplicates
FROM parcel.parcels_canonical;

-- Check market distribution
SELECT market_key, COUNT(*) AS parcel_count
FROM parcel.parcels_canonical
GROUP BY market_key
ORDER BY parcel_count DESC
LIMIT 10;