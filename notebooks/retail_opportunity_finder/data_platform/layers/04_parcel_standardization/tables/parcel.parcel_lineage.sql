-- Build parcel.parcel_lineage
-- Migrated from R: tables/parcel.parcel_lineage.R
-- Note: geometry_join_qa comes from external RDS files, so this SQL assumes
-- that data is loaded into a temporary table or handled externally

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
  -- For SQL migration, assuming geometry_join_qa is loaded externally or empty
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
