🧭 Metro Deep Dive — ACS Ingest & Silver Layer

This folder contains all scripts, functions, and documentation for the ingestion and transformation of U.S. Census American Community Survey (ACS) 5-Year Estimates into standardized Silver layer tables.
The ACS provides the demographic, economic, housing, and social backbone of the Metro Deep Dive project.

📂 Repository Structure
Path	Description
scripts/ingest_acs.R	Generic ACS ingestion function and per-topic pulls from the Census API (via tidycensus).
scripts/model_acs_to_silver.R	Silver layer modeling script — reads staging data, cleans, reshapes, and computes KPI buckets.
data/bronze/	Raw downloaded ACS CSV/XLSX files (optional if using API).
data/silver/	Standardized Silver tables output to DuckDB (silver.*)
scripts/utils.R	Shared helper functions (standardize_acs_df(), file paths, logging).
data/duckdb/metro_deep_dive.duckdb	Primary analytical database (Bronze → Silver → Gold).
⚙️ Script Overview
1. ingest_acs.R

Purpose: download ACS data programmatically for multiple years and geographies, standardize variable naming, and write to the staging schema in DuckDB.

Key functions:

get_acs_multi_year(geography, vars, state = NULL, years = 2012:2023)


Wraps tidycensus::get_acs()

Loops across years

Returns a tidy, wide-format dataset with year column

Optional state parameter for tract-level pulls

Supports multiple states simultaneously

All outputs are written as:

staging.acs_{theme}_{geo}


where {theme} = demographic area (e.g., edu, race, income)
and {geo} = geographic level (e.g., state, county, tract_nc).

2. model_acs_to_silver.R

Purpose: transform staging ACS data into standardized Silver KPIs.

Each theme follows a six-step structure:

# 1. Setup environment and DB connection
# 2. Read staging tables (by geo)
# 3. Standardize columns, drop MOEs, add geo_level
# 4. Union all geographies
# 5. Compute KPI buckets (per theme)
# 6. Write Silver base and KPI tables


Standardized helper:

standardize_acs_df(df, geo_level, drop_e = TRUE)


Renames GEOID/NAME → geo_id/geo_name

Adds geo_level

Drops all MOE columns and trailing “E” suffixes

Ensures consistent column order before union

All Silver tables are written as:

silver.{theme}_base
silver.{theme}_kpi

🧱 Silver Layer Architecture

Schema: silver
Core Columns (all themes):

geo_level, geo_id, geo_name, year, [metrics...]


Each Silver table is wide (one row per geography-year)

One _base table (raw estimates) and one _kpi table (derived metrics)

Consistent design → simplifies Gold layer joins

📊 Themes & KPIs

Below are the standardized ACS themes, source tables, and key Silver KPIs.
All cover 2012–2023 unless otherwise noted.

🧑‍🤝‍🧑 Demographics & Age

Source: B01001
KPIs:

pop_total

Age group counts (under 18, 18–64, 65+)

youth_dependency_ratio, old_age_dependency_ratio, aging_index

🌎 Race & Ethnicity

Source: B03002
KPIs:

% White, % Black, % Hispanic, % Asian, % Other

diversity_index = 1 - Σ(pᵢ²)

🎓 Education

Source: B15003
KPIs:

% < High School

% HS / GED

% Some College / Associate

% Bachelor

% Graduate+

💵 Income & Poverty

Source: B19013, B17001, B19083
KPIs:

median_hh_income

poverty_rate

gini_income

5- and 10-year income growth (Gold)

🏗️ Labor, Industry & Occupation

Source: B23025, C24010, C24030
KPIs:

lfpr, unemp_rate, emp_pop_ratio

% Professional, % Service, % Construction, % Production

% Education/Health, % Finance, % Manufacturing

industry_diversity = 1 - Σ(pct_ind_*²)

🏠 Housing & Structure

Source: B25001–B25077
KPIs:

vacancy_rate, owner_occ_rate

median_home_value, median_rent

rent_burden_30plus

rent_to_income, value_to_income (Gold)

structure_type_share (1–unit, 2–4, 5+ units)

🚚 Migration & Nativity

Source: B07003, B05002
KPIs:

% same_house_last_year, % moved_within_state, % moved_out_state

% foreign_born

mobility_rate = 1 - same_house

🚗 Transportation & Accessibility

Source: B08301, B08201, B08013
KPIs:

% drive_alone, % carpool, % transit, % WFH

% households_no_vehicle

mean_travel_time

🧑‍💻 Social & Digital Infrastructure (2015–2023 only)

Source: B11001, B28002, B27010
KPIs:

% family_households, % single_households

% broadband_access, % health_insured

% digital_inclusion_index (Gold candidate)

🧩 Metadata & Documentation

Two supporting tables describe the Silver layer:

Table	Purpose
silver.metadata_topics	One row per Silver table — counts, coverage, year range, geos.
silver.metadata_vars	One row per column per Silver table — name, type, description.
silver.kpi_dictionary	KPI name, business definition, formula notes, and source ACS table.

These tables power documentation and ensure full lineage from variable → KPI → Gold metric.

🧠 Future Gold KPIs (ACS-based)

These are derived metrics planned for the Gold layer, combining multiple Silver themes:

Category	Metric	Formula
Population Dynamics	pop_growth_5yr	Δ population / prior
	migration_rate	% moved / total pop
Affordability	rent_to_income, value_to_income	median_rent * 12 / income
Labor	lfpr_change, unemp_rate_change	Δ year-over-year
Education	share_ba_plus	% BA + Grad
Equity	gini_income, poverty_rate_change	inequality tracking
Diversity	diversity_index	1 - Σ(pᵢ²)
Access	pct_wfh, pct_hh_no_vehicle	accessibility indicators
Composite Scores	affordability_index, mobility_index, overheating_score	cross-domain indices for investment ranking
🗂️ Example Output Schema

Example: silver.housing_kpi

Column	Type	Description
geo_level	TEXT	Geographic level (US, region, division, state, county, place, zcta, tract)
geo_id	TEXT	FIPS or GEOID
geo_name	TEXT	Name of area
year	INTEGER	ACS 5-year vintage
hu_total	INTEGER	Total housing units
occ_occupied	INTEGER	Occupied units
occ_vacant	INTEGER	Vacant units
owner_occ_rate	DOUBLE	Share of occupied units that are owner-occupied
median_home_value	DOUBLE	Median owner-occupied home value
rent_burden_30plus	DOUBLE	% of renters paying >30% income on rent
…	…	…
🧩 Key Design Notes

Wide format in Silver: simplifies KPI computation and joins; Gold will pivot long.

Consistent column order: ensures reliable binding across geographies.

Versioned DuckDB storage: all ACS vintages (2012–2023) preserved.

Staging schema mirrors Census variables for easy re-ingestion.

Metadata tables auto-generated to keep documentation current.

🚀 Next Steps

Finalize crosswalk documentation (County↔CBSA, ZCTA↔County/CBSA, Tract↔County).

Begin Gold ACS builders (Population Growth, Affordability, Mobility).

Integrate BLS, BEA, and HUD data into the Gold schema.

Develop Shiny dashboards for ACS exploration and Gold KPI comparison.