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
