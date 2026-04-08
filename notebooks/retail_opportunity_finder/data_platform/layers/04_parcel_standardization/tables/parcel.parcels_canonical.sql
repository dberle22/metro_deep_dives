-- Build parcel.parcels_canonical
-- Migrated from R: tables/parcel.parcels_canonical.R

CREATE OR REPLACE TABLE parcel.parcels_canonical AS

WITH market_counties AS (
  -- Get market counties that have parcel data available
  SELECT DISTINCT
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
),

parcel_tabular AS (
  -- Query and transform parcel tabular data, filtered to market counties
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

-- Add retail classification and deduplicate
SELECT DISTINCT
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
