# 🗺️ Metro Deep Dive — Geographic Crosswalks

This folder contains the scripts and data structures we use to normalize geographies across ACS, HUD, OMB, and TIGER sources.

Because our analysis hops between county, CBSA, ZCTA, tract, state, and region/division, we need a reliable set of crosswalks stored in DuckDB (schema: silver) that all follow the same naming patterns and vintages.

This README documents:

- The script that builds the crosswalks (what it does, in what order)
- The source files used (OMB, HUD, TIGER)
- The standardized tables we materialize
- Known gaps / future improvements

# 📂 Script

File: scripts/build_crosswalks.R
Purpose: read multiple official crosswalk sources (OMB, HUD, TIGER), standardize column names and codes (GEOIDs), and write them to the silver schema in DuckDB.

High-level flow:

- Load env, paths, and connect to DuckDB
- CBSA ⇔ County (OMB 2023) 
- CBSA ⇔ Primary City (OMB 2023)
- Tract ⇔ County (TIGER 2023, currently NC/FL/GA)
- ZCTA ⇔ County (HUD ZIP→County 2025Q1)
- ZCTA ⇔ CBSA (HUD ZIP→CBSA 2025Q1)
- ZCTA ⇔ Tract (HUD ZIP→Tract 2025Q1)
- County ⇔ State (TIGER 2023)
- CBSA ⇔ State (derived from CBSA⇔County)
- State ⇔ Region / Division (static table)

All tables are written to DuckDB as:

silver.xwalk_<from>_<to>

# 🧱 Data Sources

## OMB 2023 CBSA files

- cbsa_county_xwalk_census.xlsx
- cbsa_primary_city_xwalk_census.xlsx

Both have 2 header/preamble rows → we read them with skip = 2

Considered authoritative for CBSA definitions for 2023

## HUD ZIP Crosswalks (June 2025)

- ZIP_COUNTY_062025.xlsx
- ZIP_CBSA_062025.xlsx
- ZIP_TRACT_062025.xlsx

These already contain allocation ratios (RES_RATIO, BUS_RATIO, TOT_RATIO), so we kept them

## TIGER/Line 2023

- tigris::tracts(year = 2023, cb = TRUE)
- tigris::counties(year = 2023, cb = TRUE)

Used to derive tract⇔county (for now limited to NC, FL, GA) and county⇔state

## Static Census region/division

Hand-built tibble, standard Census 4-region / 9-division mapping

## 🧪 1. CBSA ⇔ County (silver.xwalk_cbsa_county)

Source: OMB 2023 CBSA–County Excel
Read: read_excel(..., skip = 2)

Transform:

cbsa_county_xwalk_clean <- cbsa_county_xwalk_raw %>%
  select(
    cbsa_code  = `CBSA Code`,
    cbsa_name  = `CBSA Title`,
    csa_code   = `CSA Code`,
    csa_name   = `CSA Title`,
    cbsa_type  = `Metropolitan/Micropolitan Statistical Area`,
    county_name= `County/County Equivalent`,
    state_name = `State Name`,
    state_fips = `FIPS State Code`,
    county_fips= `FIPS County Code`,
    county_flag= `Central/Outlying County`
  ) %>%
  filter(!is.na(cbsa_name)) %>%
  mutate(
    cbsa_code    = as.character(cbsa_code),
    csa_code     = as.character(csa_code),
    county_geoid = sprintf("%02d%03d", as.integer(state_fips), as.integer(county_fips)),
    vintage      = 2023L,
    source       = "OMB_2023"
  )


Stored as:
silver.xwalk_cbsa_county

What it gives us:

Every 2023 CBSA → list of counties

County-level role (Central vs Outlying)

CBSA & CSA titles

Clean 5-digit county GEOIDs (county_geoid)

This is the anchor for building CBSA-level datasets from county ACS.

## 🏙️ 2. CBSA ⇔ Primary City (silver.xwalk_cbsa_primary_city)

Source: OMB 2023 Principal City file
Transform:

cbsa_city_clean <- cbsa_primary_city_xwalk_raw %>%
  select(
    cbsa_code  = `CBSA Code`,
    cbsa_name  = `CBSA Title`,
    cbsa_type  = `Metropolitan/Micropolitan Statistical Area`,
    primary_city = `Principal City Name`,
    state_fips = `FIPS State Code`,
    place_fips = `FIPS Place Code`
  ) %>%
  mutate(
    vintage = 2023L,
    source  = "OMB_2023"
  ) %>%
  filter(!is.na(cbsa_name))


Stored as:
silver.xwalk_cbsa_primary_city

Why separate?
This file is n:n (one CBSA → many cities; some cities in multiple CBSAs), so we kept it separate from the CBSA–County table. Later we can build a Gold dim_cbsa that aggregates:

number of principal cities

number of central / outlying counties

multi-state flag
…but not now.

## 🧭 3. Tract ⇔ County (silver.xwalk_tract_county)

Source: tigris::tracts(year = 2023, cb = TRUE)

Important: in the script you filtered to NC, FL, GA:

tracts_2023 %>%
  sf::st_drop_geometry() %>%
  filter(STUSPS %in% c("NC", "FL", "GA"))


So right now this table is not national — it only covers those states. That’s fine for your current Metro Deep Dive focus.

Stored as:
silver.xwalk_tract_county

Columns:

state_fip, county_fip, tract_fip, tract_geoid

names (tract_name, county_name, state_name)

vintage = 2023, source = 'TIGRIS'

Use: to roll tract ACS → county and then county → CBSA.

## 📮 4. ZCTA ⇔ County (silver.xwalk_zcta_county)

Source: HUD ZIP→County 2025Q1 Excel
Why HUD? it already has allocation ratios, so we don’t have to invent weights.

Transform:

zcta_county_xwalk_clean <- zcta_county_xwalk_raw %>%
  select(
    zip_geoid      = ZIP,
    county_geoid   = COUNTY,
    zip_pref_city  = USPS_ZIP_PREF_CITY,
    zip_pref_state = USPS_ZIP_PREF_STATE,
    rel_weight_pop = RES_RATIO,
    rel_weight_bus = BUS_RATIO,
    rel_weight_hu  = TOT_RATIO
  ) %>%
  mutate(
    zip_geoid    = str_pad(zip_geoid, 5, pad = "0"),
    county_geoid = str_pad(county_geoid, 5, pad = "0"),
    vintage      = 2025L,
    source       = "HUD_ZIP_COUNTY_2025Q1"
  )


Stored as:
silver.xwalk_zcta_county

This one is many-to-many but already weighted, so when we roll ZCTA → county we can do properly weighted aggregates.

## 🏢 5. ZCTA ⇔ CBSA (silver.xwalk_zcta_cbsa)

Source: HUD ZIP→CBSA 2025Q1
Transform is identical to the county one — we just rename to CBSA:

zcta_cbsa_xwalk_clean <- zcta_cbsa_xwalk_raw %>%
  select(
    zip_geoid      = ZIP,
    cbsa_geoid     = CBSA,
    zip_pref_city  = USPS_ZIP_PREF_CITY,
    zip_pref_state = USPS_ZIP_PREF_STATE,
    rel_weight_pop = RES_RATIO,
    rel_weight_bus = BUS_RATIO,
    rel_weight_hu  = TOT_RATIO
  ) %>%
  mutate(
    zip_geoid  = str_pad(zip_geoid, 5, pad = "0"),
    cbsa_geoid = str_pad(cbsa_geoid, 5, pad = "0"),
    vintage    = 2025L,
    source     = "HUD_ZIP_CBSA_2025Q1"
  )


Stored as:
silver.xwalk_zcta_cbsa

This gives us a direct ZCTA → CBSA relationship (with weights), which is super useful for ZCTA-level ACS or Zillow/HUD data we want to map into CBSAs.

## 🧱 6. ZCTA ⇔ Tract (silver.xwalk_zcta_tract)

Source: HUD ZIP→Tract 2025Q1

This is what lets us bridge ZIP/ZCTA data down to tracts, then up again to counties/CBSAs using our other tables.

Stored as:
silver.xwalk_zcta_tract

## 🏛️ 7. County ⇔ State (silver.xwalk_county_state)

Source: tigris::counties(year = 2023, cb = TRUE)

Transform: drop geometry, keep GEOID, names, state FIPS + abbrev.
Stored as: silver.xwalk_county_state

This makes every county row immediately “state-aware” and lets us hop to region/division.

## 🏙️ 8. CBSA ⇔ State (silver.xwalk_cbsa_state)

This one is derived — we didn’t download it. We built it from the CBSA ⇔ County mapping:

cbsa_state_xwalk_clean <- cbsa_county_xwalk_clean %>%
  group_by(cbsa_code, cbsa_name, state_fips, state_name) %>%
  summarize(counties = n()) %>%
  ungroup() %>%
  mutate(
    vintate = 2023L,  # (typo in original script, we should make it `vintage`)
    source  = "DERIVED_FROM_CBSA_COUNTY_XWALK"
  )


Stored as:
silver.xwalk_cbsa_state

This will show one row per (CBSA, State) — which is perfect for telling which CBSAs are multistate. Later we can build “primary state” by weighting with county population.

## 🧭 9. State ⇔ Region / Division (silver.xwalk_state_region)

Static tibble → written to silver.
This is the same table you outlined in the ACS README — we just persisted it next to the other crosswalks so everything geo-related is in one schema.

# 🧩 What these crosswalks enable

With these 8 tables in silver, you can do:

county → cbsa → state → region/division
(xwalk_county_state + xwalk_cbsa_state + xwalk_state_region)

tract → county → cbsa
(xwalk_tract_county + xwalk_cbsa_county)

zcta → county → cbsa
(xwalk_zcta_county + xwalk_cbsa_county)

zcta → cbsa (direct)
(xwalk_zcta_cbsa)

That’s the full “geo spine” you need for CBSA scoring and for aggregating lower-level data up to your 2023 CBSA definitions.

# ⚠️ Notes / Gaps / To-Dos

- Tract coverage is partial
- current script filters tracts to NC, FL, GA
✅ OK for now, but we should loop all 50 states + DC later
- No Place ⇔ County yet
we discussed two good options (ZCTA bridge or sf overlay)
for now this is intentionally left blank in the script
- HUD files are 2025Q1
if a new quarter is added, we should keep the old one and append with a vintage column, not overwrite

- Standardization
right now tables are named xwalk_* and not yet in the fully generic
from_geo_level / from_geoid / to_geo_level / to_geoid shape
we can add a thin Silver-standardization script later to make that uniform