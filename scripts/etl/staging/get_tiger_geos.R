# In this script we get our ACS Raw data

# Find our current directory 
getwd()

# Set up our environment ----
# Read our common libraries & set other packages
source(here::here("scripts", "utils.R"))

# Set paths for our environments
# Make sure we're reading from the project Renviron
if (file.exists(".Renviron")) readRenviron(".Renviron")

# Set our Paths - Pointing to our Bronze folder in Data
bronze_acs <- get_env_path("DATA_DEMO_RAW")
data <- get_env_path("DATA")
db_path <- paste0(data, "/duckdb", "/metro_deep_dive.duckdb")

# Connect to the DB ----
con <- dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = FALSE)

dbExecute(con, "INSTALL spatial;")
dbExecute(con, "LOAD spatial;")

# optional: make a schema for geometries
dbExecute(con, "CREATE SCHEMA IF NOT EXISTS metro_deep_dive.geo;")

# Set Vars 
year <- 2024
SQM_PER_SQMI <- 2589988.110336

# ---- Helper: write sf -> duckdb with WKB + (optional) DuckDB geom column ----
write_sf_duckdb <- function(con, sf_obj, fq_table, make_geom_col = TRUE) {
  stopifnot(inherits(sf_obj, "sf"))
  
  # Build DF with WKB as a DB-friendly blob vector
  wkb <- sf::st_as_binary(sf::st_geometry(sf_obj))
  geom_wkb <- blob::as_blob(unclass(wkb))
  
  df <- sf::st_drop_geometry(sf_obj)
  df$geom_wkb <- geom_wkb
  
  # Register DF in DuckDB
  tmp_name <- paste0("tmp_", as.integer(runif(1, 1e7, 9e7)))
  duckdb::duckdb_register(con, tmp_name, df)
  
  # Create/replace target table from registered DF
  DBI::dbExecute(con, sprintf("CREATE OR REPLACE TABLE %s AS SELECT * FROM %s;", fq_table, tmp_name))
  
  # Optional: create DuckDB GEOMETRY column
  if (make_geom_col) {
    DBI::dbExecute(con, sprintf("ALTER TABLE %s ADD COLUMN IF NOT EXISTS geom GEOMETRY;", fq_table))
    DBI::dbExecute(con, sprintf("UPDATE %s SET geom = ST_GeomFromWKB(geom_wkb);", fq_table))
  }
  
  # Unregister temp
  duckdb::duckdb_unregister(con, tmp_name)
  
  invisible(TRUE)
}

# Download TIGER Geometries ----
## States ----
states <- tigris::states(cb = TRUE, year = year) %>%
  rename(state_fips = STATEFP, state_abbr = STUSPS, state_name = NAME)

write_sf_duckdb(con, states, "metro_deep_dive.geo.states")

### Tests
dbGetQuery(con, "SELECT COUNT(*) n FROM metro_deep_dive.geo.states;")
dbGetQuery(con, "SELECT typeof(geom_wkb) AS wkb_type, typeof(geom) AS geom_type FROM metro_deep_dive.geo.states LIMIT 1;")

## CBSAs ----
cbsa_all <- tigris::core_based_statistical_areas(cb = TRUE, year = year) %>%
  rename(cbsa_code = CBSAFP, cbsa_name = NAME, cbsa_name_long = NAMELSAD)

write_sf_duckdb(con, cbsa_all, "metro_deep_dive.geo.cbsas")

## Counties ----
counties <- tigris::counties(cb = TRUE, year = year) %>%
  mutate(county_geoid = paste0(STATEFP, COUNTYFP),
         state_fips = STATEFP, 
         county_fips = COUNTYFP, 
         county_name = NAME,
         aland_m2 = as.numeric(ALAND),
         awater_m2 = as.numeric(AWATER),
         land_area_sqmi  = aland_m2 / SQM_PER_SQMI,
         water_area_sqmi = awater_m2 / SQM_PER_SQMI)

write_sf_duckdb(con, counties, "metro_deep_dive.geo.counties")

## Tracts FL ----
tracts_fl <- tigris::tracts(state = "FL", cb = TRUE, year = year) %>%
  mutate(
    tract_geoid  = GEOID,
    state_fips   = STATEFP,
    county_fips  = COUNTYFP,
    county_geoid = paste0(STATEFP, COUNTYFP),
    tract_name   = NAME,
    aland_m2 = as.numeric(ALAND),
    awater_m2 = as.numeric(AWATER),
    land_area_sqmi  = aland_m2 / SQM_PER_SQMI,
    water_area_sqmi = awater_m2 / SQM_PER_SQMI
  )

write_sf_duckdb(con, tracts_fl, "metro_deep_dive.geo.tracts_fl")

# Validations ----
print(dbGetQuery(con, "SELECT COUNT(*) n FROM metro_deep_dive.geo.states;"))
print(dbGetQuery(con, "SELECT COUNT(*) n FROM metro_deep_dive.geo.cbsas;"))
print(dbGetQuery(con, "SELECT COUNT(*) n FROM metro_deep_dive.geo.counties;"))
print(dbGetQuery(con, "SELECT COUNT(*) n FROM metro_deep_dive.geo.tracts_fl;"))

# Quick column checks
print(dbGetQuery(con, "DESCRIBE metro_deep_dive.geo.tracts_fl;"))

# Land area sanity (tracts)
print(dbGetQuery(con, "
  SELECT
    MIN(land_area_sqmi) min_sqmi,
    MAX(land_area_sqmi) max_sqmi,
    AVG(land_area_sqmi) avg_sqmi
  FROM metro_deep_dive.geo.tracts_fl;
"))

dbDisconnect(con, shutdown = TRUE)
