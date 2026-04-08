-- Build qa.parcel_validation_results
-- Migrated from R: tables/qa.parcel_validation_results.R

WITH validation_checks AS (
  -- Check 1: Unique parcel_uid in parcels_canonical
  SELECT
    'parcel_canonical_unique_parcel_uid' AS check_name,
    COUNT(*) - COUNT(DISTINCT parcel_uid) AS duplicates,
    CASE WHEN COUNT(*) - COUNT(DISTINCT parcel_uid) = 0 THEN TRUE ELSE FALSE END AS pass,
    'Duplicate parcel_uid rows: ' || CAST(COUNT(*) - COUNT(DISTINCT parcel_uid) AS VARCHAR) AS details
  FROM parcel.parcels_canonical

  UNION ALL

  -- Check 2: Missing join_key
  SELECT
    'parcel_canonical_missing_join_key' AS check_name,
    SUM(CASE WHEN qa_missing_join_key THEN 1 ELSE 0 END) AS metric_value,
    CASE WHEN SUM(CASE WHEN qa_missing_join_key THEN 1 ELSE 0 END) = 0 THEN TRUE ELSE FALSE END AS pass,
    'Rows with missing join_key: ' || CAST(SUM(CASE WHEN qa_missing_join_key THEN 1 ELSE 0 END) AS VARCHAR) AS details
  FROM parcel.parcels_canonical

  UNION ALL

  -- Check 3: Missing county_geoid
  SELECT
    'parcel_canonical_missing_county_geoid' AS check_name,
    SUM(CASE WHEN county_geoid IS NULL OR county_geoid = '' THEN 1 ELSE 0 END) AS metric_value,
    CASE WHEN SUM(CASE WHEN county_geoid IS NULL OR county_geoid = '' THEN 1 ELSE 0 END) = 0 THEN TRUE ELSE FALSE END AS pass,
    'Rows with missing county_geoid: ' || CAST(SUM(CASE WHEN county_geoid IS NULL OR county_geoid = '' THEN 1 ELSE 0 END) AS VARCHAR) AS details
  FROM parcel.parcels_canonical

  UNION ALL

  -- Check 4: Unmapped land_use_codes
  SELECT
    'parcel_land_use_mapping_unmapped_codes' AS check_name,
    COUNT(DISTINCT pc.land_use_code) AS metric_value,
    CASE WHEN COUNT(DISTINCT pc.land_use_code) = 0 THEN TRUE ELSE FALSE END AS pass,
    'Distinct unmapped land_use_code values: ' || CAST(COUNT(DISTINCT pc.land_use_code) AS VARCHAR) AS details
  FROM parcel.parcels_canonical pc
  WHERE pc.land_use_code IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM ref.land_use_mapping lum
      WHERE LPAD(TRIM(CAST(lum.land_use_code AS VARCHAR)), 3, '0') = pc.land_use_code
    )

  UNION ALL

  -- Check 5: Missing counties in parcel_join_qa (using parcel_lineage)
  SELECT
    'parcel_join_qa_missing_counties' AS check_name,
    COUNT(*) AS metric_value,
    CASE WHEN COUNT(*) = 0 THEN TRUE ELSE FALSE END AS pass,
    'Parcel-backed market counties without geometry QA lineage: ' || CAST(COUNT(*) AS VARCHAR) AS details
  FROM parcel.parcel_lineage pl
  WHERE pl.analysis_path IS NULL OR pl.analysis_path = ''

  UNION ALL

  -- Check 6: Failed counties in parcel_join_qa
  SELECT
    'parcel_join_qa_failed_counties' AS check_name,
    SUM(CASE WHEN pass = FALSE THEN 1 ELSE 0 END) AS metric_value,
    CASE WHEN SUM(CASE WHEN pass = FALSE THEN 1 ELSE 0 END) = 0 THEN TRUE ELSE FALSE END AS pass,
    'Counties with geometry QA pass == FALSE: ' || CAST(SUM(CASE WHEN pass = FALSE THEN 1 ELSE 0 END) AS VARCHAR) AS details
  FROM parcel.parcel_lineage

  UNION ALL

  -- Check 7: High unmatched rate counties
  SELECT
    'parcel_join_qa_high_unmatched_rate_counties' AS check_name,
    SUM(CASE WHEN unmatched_rate_analysis > 0.02 THEN 1 ELSE 0 END) AS metric_value,
    CASE WHEN SUM(CASE WHEN unmatched_rate_analysis > 0.02 THEN 1 ELSE 0 END) = 0 THEN TRUE ELSE FALSE END AS pass,
    'Counties with unmatched_rate_analysis > 0.02: ' || CAST(SUM(CASE WHEN unmatched_rate_analysis > 0.02 THEN 1 ELSE 0 END) AS VARCHAR) AS details
  FROM parcel.parcel_lineage
  WHERE unmatched_rate_analysis IS NOT NULL

  UNION ALL

  -- Check 8: Zero parcel counties
  SELECT
    'parcel_lineage_zero_parcel_counties' AS check_name,
    SUM(CASE WHEN distinct_parcels = 0 THEN 1 ELSE 0 END) AS metric_value,
    CASE WHEN SUM(CASE WHEN distinct_parcels = 0 THEN 1 ELSE 0 END) = 0 THEN TRUE ELSE FALSE END AS pass,
    'Parcel-backed market counties with zero published parcels: ' || CAST(SUM(CASE WHEN distinct_parcels = 0 THEN 1 ELSE 0 END) AS VARCHAR) AS details
  FROM parcel.parcel_lineage
)

SELECT
  check_name,
  CASE
    WHEN check_name LIKE '%high_unmatched%' OR check_name LIKE '%zero_parcel%' THEN 'warning'
    ELSE 'error'
  END AS severity,
  CASE
    WHEN check_name LIKE 'parcel_canonical%' THEN 'parcel.parcels_canonical'
    WHEN check_name LIKE 'parcel_land_use%' THEN 'parcel.retail_parcels'
    WHEN check_name LIKE 'parcel_join_qa%' THEN 'parcel.parcel_join_qa'
    WHEN check_name LIKE 'parcel_lineage%' THEN 'parcel.parcel_lineage'
    ELSE NULL
  END AS dataset,
  metric_value,
  pass,
  details,
  'data_platform/layers/04_parcel_standardization' AS build_source,
  CAST(NOW() AS VARCHAR) AS run_timestamp
FROM validation_checks
ORDER BY check_name;
