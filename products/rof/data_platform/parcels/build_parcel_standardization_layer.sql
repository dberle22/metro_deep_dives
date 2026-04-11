-- Layer 04 Parcel Standardization SQL Migration
-- Execute this script in DuckDB to build all parcel standardization tables
-- Order matters due to dependencies

-- Note: This assumes geometry_join_qa data is not available in SQL.
-- If geometry_join_qa needs to be loaded, do so before running parcel_lineage.

-- 1. Create parcels_canonical
CREATE OR REPLACE TABLE parcel.parcels_canonical AS
-- Build parcel.parcels_canonical
-- Migrated from R: tables/parcel.parcels_canonical.R

WITH market_counties AS (
  -- Get market counties that have parcel data available
  SELECT
    mcm.market_key,
    mcm.cbsa_code,
    mcm.county_geoid,
    mcm.county_name,
    mcm.state_fips,
    mcm.county_fips,
    mcm.state_abbr,
    -- Normalized fields
    LPAD(CAST(mcm.county_fips AS VARCHAR), 3, '0') AS county_fips_norm,
    CAST(mcm.county_fips AS VARCHAR) AS county_code_norm,
    'co_' || CAST(mcm.county_fips AS VARCHAR) AS county_tag_norm,
    REGEXP_REPLACE(LOWER(REGEXP_REPLACE(mcm.county_name, '[^a-zA-Z0-9]', '')), 'county$', '') AS county_name_key
  FROM ref.market_county_membership mcm
  INNER JOIN (
    SELECT DISTINCT
      UPPER(TRIM(ptc.state)) AS state_abbr,
      ptc.county_geoid,
      LPAD(CAST(ptc.county_fips AS VARCHAR), 3, '0') AS county_fips_norm,
      REGEXP_REPLACE(LOWER(REGEXP_REPLACE(ptc.county_name, '[^a-zA-Z0-9]', '')), 'county$', '') AS county_name_key
    FROM rof_parcel.parcel_tabular_clean ptc
    WHERE ptc.state IS NOT NULL AND ptc.county_name IS NOT NULL
  ) parcel_counties
  ON UPPER(TRIM(mcm.state_abbr)) = parcel_counties.state_abbr
    AND mcm.county_geoid = parcel_counties.county_geoid
    AND mcm.county_fips = CAST(parcel_counties.county_fips_norm AS INTEGER)
    -- AND mcm.county_name_key = parcel_counties.county_name_key
),

parcel_tabular AS (
  -- Query and transform parcel tabular data
  SELECT
    UPPER(TRIM(ptc.state)) AS state_abbr_source,
    CAST(ptc.county_geoid AS VARCHAR) AS county_geoid_source,
    LPAD(CAST(ptc.county_fips AS VARCHAR), 3, '0') AS county_fips_source,
    CAST(ptc.county_code AS VARCHAR) AS source_county_code,
    NULLIF(TRIM(CAST(ptc.census_block_id AS VARCHAR)), '') AS census_block_id,
    TRIM(CAST(ptc.join_key AS VARCHAR)) AS join_key,
    CAST(ptc.parcel_id AS VARCHAR) AS parcel_id,
    CAST(ptc.alt_key AS VARCHAR) AS alt_key,
    CAST(ptc.county_name AS VARCHAR) AS county_name_source,
    REGEXP_REPLACE(LOWER(REGEXP_REPLACE(ptc.county_name, '[^a-zA-Z0-9]', '')), 'county$', '') AS county_name_key,
    LPAD(TRIM(CAST(ptc.use_code AS VARCHAR)), 3, '0') AS land_use_code,
    CAST(ptc.owner_name AS VARCHAR) AS owner_name,
    CAST(ptc.owner_addr AS VARCHAR) AS owner_addr,
    CAST(ptc.phys_addr AS VARCHAR) AS site_addr,
    CAST(ptc.just_value AS DECIMAL) AS just_value,
    CAST(ptc.land_value AS DECIMAL) AS land_value,
    CAST(ptc.impro_value AS DECIMAL) AS impro_value,
    CAST(ptc.total_value AS DECIMAL) AS total_value,
    CAST(ptc.living_area_sqft AS DECIMAL) AS living_area_sqft,
    CAST(ptc.sale_qual_code AS VARCHAR) AS sale_qual_code,
    CAST(ptc.sale_price1 AS DECIMAL) AS last_sale_price,
    CAST(ptc.sale_yr1 AS INTEGER) AS sale_yr1,
    CASE
      WHEN CAST(ptc.sale_mo1 AS INTEGER) BETWEEN 1 AND 12 THEN CAST(ptc.sale_mo1 AS INTEGER)
      ELSE NULL
    END AS sale_mo1,
    ptc.source_file,
    ptc.county_tag AS source_county_tag
  FROM rof_parcel.parcel_tabular_clean ptc
  INNER JOIN market_counties mc
  ON UPPER(TRIM(ptc.state)) = mc.state_abbr
    AND UPPER(TRIM(ptc.county_name)) = UPPER(TRIM(mc.county_name))
),

parcel_with_market AS (
  -- Join with market counties lookup and coalesce fields
  SELECT
    pt.*,
    mc.market_key,
    mc.cbsa_code,
    mc.state_fips,
    -- Coalesce county fields
    COALESCE(mc.county_geoid, pt.county_geoid_source) AS county_geoid,
    COALESCE(mc.county_fips_norm, pt.county_fips_source) AS county_fips,
    COALESCE(mc.county_code_norm, pt.source_county_code) AS county_code,
    COALESCE(mc.county_tag_norm, CASE WHEN pt.source_county_tag IS NOT NULL THEN pt.source_county_tag ELSE 'co_' || CAST(CAST(pt.county_fips_source AS INTEGER) AS VARCHAR) END) AS county_tag,
    COALESCE(mc.county_name, pt.county_name_source) AS county_name,
    -- Build parcel_uid
    pt.source_county_code || '::' || pt.join_key AS parcel_uid,
    -- QA flags
    CASE WHEN pt.join_key IS NULL OR pt.join_key = '' THEN TRUE ELSE FALSE END AS qa_missing_join_key,
    CASE WHEN pt.source_county_code IS NULL OR pt.source_county_code = '' OR pt.source_county_code = '0' THEN TRUE ELSE FALSE END AS qa_zero_county,
    -- Metadata
    NULL AS ingest_run_id,
    'rof_parcel.parcel_tabular_clean_current' AS transform_version,
    'rof_parcel.parcel_tabular_clean filtered to parcel-backed ref.market_county_membership counties' AS build_source,
    CAST(NOW() AS VARCHAR) AS run_timestamp
  FROM parcel_tabular pt
  LEFT JOIN market_counties mc
  ON pt.state_abbr_source = mc.state_abbr
    AND pt.county_name_key = mc.county_name_key
),

parcel_canonical_base AS (
  SELECT
    market_key,
    cbsa_code,
    state_abbr_source AS state_abbr,
    state_fips,
    county_fips,
    county_geoid,
    county_code,
    county_tag,
    county_name,
    county_name_key,
    source_county_code,
    source_county_tag,
    county_name_source,
    source_file,
    ingest_run_id,
    transform_version,
    parcel_uid,
    parcel_id,
    alt_key,
    join_key,
    census_block_id,
    land_use_code,
    owner_name,
    owner_addr,
    site_addr,
    living_area_sqft,
    just_value,
    land_value,
    impro_value,
    total_value,
    sale_qual_code,
    last_sale_price,
    CASE
      WHEN sale_yr1 IS NOT NULL AND sale_mo1 IS NOT NULL THEN MAKE_DATE(sale_yr1, sale_mo1, 1)
      ELSE NULL
    END AS last_sale_date,
    qa_missing_join_key,
    qa_zero_county,
    build_source,
    run_timestamp
  FROM parcel_with_market
)

-- Add retail classification
SELECT
  pcb.*,
  lum.category AS land_use_category,
  lum.description AS land_use_description,
  COALESCE(lum.retail_flag, FALSE) AS retail_flag,
  CASE
    WHEN COALESCE(lum.retail_flag, FALSE) AND lum.retail_subtype IS NULL THEN 'retail_uncategorized'
    ELSE lum.retail_subtype
  END AS retail_subtype,
  CASE
    WHEN COALESCE(lum.retail_flag, FALSE) THEN 'Retail parcel'
    ELSE 'Residential/other parcel'
  END AS parcel_segment,
  lum.review_note,
  lum.mapping_version,
  lum.mapping_method,
  lum.classification_source_path,
  'parcel.parcels_canonical + ref.land_use_mapping' AS build_source,
  CAST(NOW() AS VARCHAR) AS run_timestamp
FROM parcel_canonical_base pcb
LEFT JOIN ref.land_use_mapping lum
ON pcb.land_use_code = LPAD(TRIM(CAST(lum.land_use_code AS VARCHAR)), 3, '0')
ORDER BY market_key, county_geoid, parcel_uid;

-- 2. Create parcel_lineage
CREATE OR REPLACE TABLE parcel.parcel_lineage AS
-- Build parcel.parcel_lineage
-- Migrated from R: tables/parcel.parcel_lineage.R
-- Note: geometry_join_qa comes from external RDS files, so this SQL assumes
-- that data is not available in SQL. If geometry_join_qa needs to be loaded,
-- load it into a temp table and join here.

WITH market_counties AS (
  -- Get market counties that have parcel data available
  SELECT
    mcm.market_key,
    mcm.cbsa_code,
    mcm.county_geoid,
    mcm.county_name,
    mcm.state_fips,
    mcm.county_fips,
    mcm.state_abbr,
    -- Normalized fields
    LPAD(CAST(mcm.county_fips AS VARCHAR), 3, '0') AS county_fips_norm,
    CAST(mcm.county_fips AS VARCHAR) AS county_code_norm,
    'co_' || CAST(mcm.county_fips AS VARCHAR) AS county_tag_norm,
    REGEXP_REPLACE(LOWER(REGEXP_REPLACE(mcm.county_name, '[^a-zA-Z0-9]', '')), 'county$', '') AS county_name_key
  FROM ref.market_county_membership mcm
  INNER JOIN (
    SELECT DISTINCT
      UPPER(TRIM(ptc.state)) AS state_abbr,
      ptc.county_geoid,
      LPAD(CAST(ptc.county_fips AS VARCHAR), 3, '0') AS county_fips_norm,
      REGEXP_REPLACE(LOWER(REGEXP_REPLACE(ptc.county_name, '[^a-zA-Z0-9]', '')), 'county$', '') AS county_name_key
    FROM rof_parcel.parcel_tabular_clean ptc
    WHERE ptc.state IS NOT NULL AND ptc.county_name IS NOT NULL
  ) parcel_counties
  ON UPPER(TRIM(mcm.state_abbr)) = parcel_counties.state_abbr
    AND mcm.county_geoid = parcel_counties.county_geoid
    AND mcm.county_fips = CAST(parcel_counties.county_fips_norm AS INTEGER)
    AND mcm.county_name_key = parcel_counties.county_name_key
),

parcel_counts AS (
  -- Get parcel counts from parcels_canonical
  SELECT
    market_key,
    county_geoid,
    county_fips,
    COUNT(*) AS parcel_rows,
    COUNT(DISTINCT parcel_uid) AS distinct_parcels
  FROM parcel.parcels_canonical
  GROUP BY market_key, county_geoid, county_fips
),

county_lineage_base AS (
  -- Base lineage from market_counties
  -- Note: In R version, this would be joined with geometry_join_qa if available
  -- For SQL migration, assuming geometry_join_qa is not available
  SELECT
    mc.market_key,
    mc.cbsa_code,
    mc.state_abbr,
    mc.state_fips,
    mc.county_fips_norm AS county_fips,
    mc.county_geoid,
    mc.county_name,
    mc.county_tag_norm AS county_tag,
    mc.county_name_key,
    NULL AS source_county_tag,
    NULL AS source_county_code,
    NULL AS source_shp,
    NULL AS output_dir,
    NULL AS raw_path,
    NULL AS analysis_path,
    NULL AS qa_path,
    NULL AS total_rows_raw,
    NULL AS unmatched_rows_raw,
    NULL AS unmatched_rate_raw,
    NULL AS total_rows_analysis,
    NULL AS unmatched_rows_analysis,
    NULL AS unmatched_rate_analysis,
    NULL AS pass
  FROM market_counties mc
  -- LEFT JOIN geometry_join_qa gjq ON ... (external data)
),

load_log_latest AS (
  -- Get latest load log per county
  SELECT
    ll.ingest_run_id,
    UPPER(TRIM(ll.state)) AS state_abbr,
    ll.county_tag,
    ll.county_name,
    COALESCE(ll.county_fips, CAST(REGEXP_EXTRACT(ll.county_tag, '[0-9]+') AS INTEGER)) AS county_fips,
    ll.source_county_id,
    ll.source_file,
    ll.source_shp,
    ll.source_shp_path,
    ll.raw_path,
    ll.analysis_keep_duplicates_path,
    ll.analysis_path,
    ll.qa_path,
    ll.duplicate_groups,
    ll.duplicate_rows,
    ll.dissolve_fallback_rows,
    ll.total_rows_raw,
    ll.unmatched_rows_raw,
    ll.unmatched_rate_raw,
    ll.total_rows_analysis,
    ll.unmatched_rows_analysis,
    ll.unmatched_rate_analysis,
    ll.transform_version,
    ll.generated_at,
    ll.pass,
    ll.load_completed_at,
    ll.load_status,
    ll.load_note,
    REGEXP_REPLACE(LOWER(REGEXP_REPLACE(ll.county_name, '[^a-zA-Z0-9]', '')), 'county$', '') AS county_name_key
  FROM rof_parcel.parcel_county_load_log ll
  INNER JOIN market_counties mc
  ON UPPER(TRIM(ll.state)) = mc.state_abbr
    AND REGEXP_REPLACE(LOWER(REGEXP_REPLACE(ll.county_name, '[^a-zA-Z0-9]', '')), 'county$', '') = mc.county_name_key
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY UPPER(TRIM(ll.state)), REGEXP_REPLACE(LOWER(REGEXP_REPLACE(ll.county_name, '[^a-zA-Z0-9]', '')), 'county$', '')
    ORDER BY ll.load_completed_at DESC, ll.generated_at DESC, ll.ingest_run_id DESC
  ) = 1
)

SELECT
  clb.market_key,
  clb.cbsa_code,
  clb.state_abbr,
  clb.state_fips,
  COALESCE(clb.county_fips, ll.county_fips) AS county_fips,
  clb.county_geoid,
  COALESCE(clb.county_name, ll.county_name) AS county_name,
  COALESCE(clb.county_tag, ll.county_tag) AS county_tag,
  clb.county_name_key,
  COALESCE(clb.source_county_tag, ll.source_county_id) AS source_county_tag,
  clb.source_county_code,
  COALESCE(clb.source_shp, ll.source_shp) AS source_shp,
  ll.source_shp_path,
  COALESCE(clb.raw_path, ll.raw_path) AS raw_path,
  ll.analysis_keep_duplicates_path,
  COALESCE(clb.analysis_path, ll.analysis_path) AS analysis_path,
  COALESCE(clb.qa_path, ll.qa_path) AS qa_path,
  ll.transform_version,
  ll.generated_at,
  COALESCE(clb.load_completed_at, ll.load_completed_at) AS load_completed_at,
  ll.load_status,
  ll.load_note,
  pc.parcel_rows,
  pc.distinct_parcels,
  ll.duplicate_groups,
  ll.duplicate_rows,
  ll.dissolve_fallback_rows,
  COALESCE(clb.total_rows_raw, ll.total_rows_raw) AS total_rows_raw,
  COALESCE(clb.unmatched_rows_raw, ll.unmatched_rows_raw) AS unmatched_rows_raw,
  COALESCE(clb.unmatched_rate_raw, ll.unmatched_rate_raw) AS unmatched_rate_raw,
  COALESCE(clb.total_rows_analysis, ll.total_rows_analysis) AS total_rows_analysis,
  COALESCE(clb.unmatched_rows_analysis, ll.unmatched_rows_analysis) AS unmatched_rows_analysis,
  COALESCE(clb.unmatched_rate_analysis, ll.unmatched_rate_analysis) AS unmatched_rate_analysis,
  COALESCE(clb.pass, ll.pass) AS pass,
  CASE
    WHEN ll.load_status IS NOT NULL THEN 'rof_parcel.parcel_county_load_log + parcel_geometry_join_qa_county_summary.rds'
    WHEN clb.analysis_path IS NOT NULL THEN 'parcel_geometry_join_qa_county_summary.rds'
    ELSE 'market_counties_only'
  END AS lineage_source,
  'ref.market_county_membership + parcel geometry QA + county load log + parcel counts' AS build_source,
  CAST(NOW() AS VARCHAR) AS run_timestamp
FROM county_lineage_base clb
LEFT JOIN load_log_latest ll
ON clb.state_abbr = ll.state_abbr
  AND clb.county_name_key = ll.county_name_key
LEFT JOIN parcel_counts pc
ON clb.market_key = pc.market_key
  AND clb.county_geoid = pc.county_geoid
  AND clb.county_fips = pc.county_fips
ORDER BY market_key, county_geoid;

-- 3. Create parcel_join_qa (archive)
CREATE OR REPLACE TABLE parcel.parcel_join_qa AS
-- Build parcel.parcel_join_qa (archive)
-- Migrated from R: tables/archive/parcel.parcel_join_qa.R
-- This is a compatibility projection of parcel.parcel_lineage

SELECT
  market_key,
  cbsa_code,
  state_abbr,
  state_fips,
  county_fips,
  county_geoid,
  county_name,
  county_tag,
  source_shp,
  NULL AS output_dir,
  raw_path,
  analysis_path,
  qa_path,
  total_rows_raw,
  unmatched_rows_raw,
  unmatched_rate_raw,
  total_rows_analysis,
  unmatched_rows_analysis,
  unmatched_rate_analysis,
  pass,
  'parcel.parcel_lineage compatibility projection' AS build_source,
  CAST(NOW() AS VARCHAR) AS run_timestamp
FROM parcel.parcel_lineage
ORDER BY county_geoid;

-- 4. Create retail_parcels (archive)
CREATE OR REPLACE TABLE parcel.retail_parcels AS
-- Build parcel.retail_parcels (archive)
-- Migrated from R: tables/archive/parcel.retail_parcels.R
-- This is a filtered subset of parcel.parcels_canonical where retail_flag = true

SELECT *
FROM parcel.parcels_canonical
WHERE retail_flag = TRUE
ORDER BY county_geoid, parcel_uid;

-- 5. Create qa_unmapped_use_codes
CREATE OR REPLACE TABLE qa.parcel_unmapped_use_codes AS
-- Build qa.parcel_unmapped_use_codes
-- Migrated from R: tables/qa.parcel_unmapped_use_codes.R

SELECT
  pc.land_use_code,
  COUNT(*) AS parcel_count,
  'parcel.parcels_canonical anti-join ref.land_use_mapping' AS build_source,
  CAST(NOW() AS VARCHAR) AS run_timestamp
FROM parcel.parcels_canonical pc
WHERE pc.land_use_code IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM ref.land_use_mapping lum
    WHERE LPAD(TRIM(CAST(lum.land_use_code AS VARCHAR)), 3, '0') = pc.land_use_code
  )
GROUP BY pc.land_use_code
ORDER BY parcel_count DESC;

-- 6. Create qa_validation_results
CREATE OR REPLACE TABLE qa.parcel_validation_results AS
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