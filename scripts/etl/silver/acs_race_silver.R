# In this script we model ACS Data to Silver

# 1. Set up our Environment
# 2. Read in our Staging Data to R Data Frames
# 3. Add Geo Level to each table, drop _M, rename columns
# 4. Build CBSA level data
# 5. Union our Data Frames together
# 6. Compute buckets and select main columns
# 7. Materialize to Silver

# 1. Set up our Environment ----
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

# 2. Read in our Staging Data to R Data Frames ----
us_acs_stage <- dbGetQuery(con, "SELECT * FROM staging.acs_race_us")
region_acs_stage <- dbGetQuery(con, "SELECT * FROM staging.acs_race_region")
division_acs_stage <- dbGetQuery(con, "SELECT * FROM staging.acs_race_division")
state_acs_stage <- dbGetQuery(con, "SELECT * FROM staging.acs_race_state")
county_acs_stage <- dbGetQuery(con, "SELECT * FROM staging.acs_race_county")
place_acs_stage <- dbGetQuery(con, "SELECT * FROM staging.acs_race_place")
zcta_acs_stage <- dbGetQuery(con, "SELECT * FROM staging.acs_race_zcta")
tract_fl_acs_stage <- dbGetQuery(con, "SELECT * FROM staging.acs_race_tract_fl")
tract_ga_acs_stage <- dbGetQuery(con, "SELECT * FROM staging.acs_race_tract_ga")
tract_nc_acs_stage <- dbGetQuery(con, "SELECT * FROM staging.acs_race_tract_nc")

# 3. Add Geo Level to each table, drop _M, rename columns ----
us_acs_clean <- standardize_acs_df(us_acs_stage, "US", drop_e = FALSE)
region_acs_clean <- standardize_acs_df(region_acs_stage, "Region")
division_acs_clean<- standardize_acs_df(division_acs_stage, "division")
state_acs_clean   <- standardize_acs_df(state_acs_stage, "state")
county_acs_clean  <- standardize_acs_df(county_acs_stage, "county")
place_acs_clean   <- standardize_acs_df(place_acs_stage, "place")
zcta_acs_clean    <- standardize_acs_df(zcta_acs_stage, "zcta")
tract_nc_clean    <- standardize_acs_df(tract_nc_acs_stage, "tract")
tract_fl_clean    <- standardize_acs_df(tract_fl_acs_stage, "tract")
tract_ga_clean    <- standardize_acs_df(tract_ga_acs_stage, "tract")

# 4. Union our Data Frames together ----
# Union Tracts together
tract_all_clean <- dplyr::bind_rows(
  tract_nc_clean,
  tract_fl_clean,
  tract_ga_clean
)

all_acs_clean <- dplyr::bind_rows(
  us_acs_clean,
  region_acs_clean,
  division_acs_clean,
  state_acs_clean,
  county_acs_clean,
  place_acs_clean,
  zcta_acs_clean,
  tract_all_clean
)

# 5. Compute buckets and select main columns ----
race_silver_kpi <- all_acs_clean %>%
  mutate(
    race_total      = pop_total_b03002E,
    race_white_nh   = white_nonhispE,
    race_black_nh   = black_nonhispE,
    race_aian_nh    = amind_nonhispE,
    race_asian_nh   = asian_nonhispE,
    race_nhpi_nh    = pacisl_nonhispE,
    race_other_nh   = other_nonhispE,
    race_two_plus_nh= two_plus_nonhispE,
    race_hispanic   = hispanic_anyE
  ) %>%
  mutate(
    pct_white_nh    = race_white_nh    / race_total,
    pct_black_nh    = race_black_nh    / race_total,
    pct_aian_nh     = race_aian_nh     / race_total,
    pct_asian_nh    = race_asian_nh    / race_total,
    pct_nhpi_nh     = race_nhpi_nh     / race_total,
    pct_other_nh    = race_other_nh    / race_total,
    pct_two_plus_nh = race_two_plus_nh / race_total,
    pct_hispanic    = race_hispanic    / race_total
  ) %>%
  mutate(
    diversity_index = 1 - (
      pct_white_nh^2 + pct_black_nh^2 + pct_aian_nh^2 + pct_asian_nh^2 +
        pct_nhpi_nh^2 + pct_other_nh^2 + pct_two_plus_nh^2 + pct_hispanic^2
    )
  ) %>%
  select(
    geo_level, geo_id, geo_name, year,
    race_total,
    race_white_nh, race_black_nh, race_aian_nh, race_asian_nh,
    race_nhpi_nh, race_other_nh, race_two_plus_nh, race_hispanic,
    pct_white_nh, pct_black_nh, pct_aian_nh, pct_asian_nh,
    pct_nhpi_nh, pct_other_nh, pct_two_plus_nh, pct_hispanic,
    diversity_index
  )

# 6. Materialize to Silver DB ----
DBI::dbWriteTable(con, DBI::Id(schema="silver", table="race_base"),
                  all_acs_clean, overwrite = TRUE)

DBI::dbWriteTable(con, DBI::Id(schema="silver", table="race_kpi"),
                  race_silver_kpi, overwrite = TRUE)

dbDisconnect(con, shutdown = TRUE)