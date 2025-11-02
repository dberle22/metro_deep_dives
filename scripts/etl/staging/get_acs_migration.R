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

# Load ACS Vars ----
acs_v23 <- load_variables(year = '2023', dataset = "acs5", cache = TRUE)
acs_v15 <- load_variables(year = '2015', dataset = "acs5", cache = TRUE)


# Migration
vars <- c(
  mig_total          = "B07003_001",
  mig_same_house     = "B07003_004",
  mig_moved_same_cnty= "B07003_007",
  mig_moved_same_st  = "B07003_010",
  mig_moved_diff_st  = "B07003_013",
  mig_moved_abroad   = "B07003_016"
)

# Ingest Data ----

# US ----
us_acs_raw <- acs_ingest(
  geography = "us",
  years     = 2012:2023,
  variables = vars,
  survey    = "acs5",
  output    = "wide"
)

# Name tables Source <> KPI <> Gran
dbWriteTable(con, 
             DBI::Id(schema = "staging", table = "acs_migration_us"),
             us_acs_raw, 
             overwrite = TRUE)

# Region ----
region_acs_raw <- acs_ingest(
  geography = "region",
  years     = 2012:2023,
  variables = vars,
  survey    = "acs5",
  output    = "wide"
)

# Name tables Source <> KPI <> Gran
dbWriteTable(con, 
             DBI::Id(schema = "staging", table = "acs_migration_region"),
             region_acs_raw, 
             overwrite = TRUE)


# Division ----
division_acs_raw <- acs_ingest(
  geography = "division",
  years     = 2012:2023,
  variables = vars,
  survey    = "acs5",
  output    = "wide"
)

# Name tables Source <> KPI <> Gran
dbWriteTable(con, 
             DBI::Id(schema = "staging", table = "acs_migration_division"),
             division_acs_raw, 
             overwrite = TRUE)

# State ----
state_acs_raw <- acs_ingest(
  geography = "state",
  years     = 2012:2023,
  variables = vars,
  survey    = "acs5",
  output    = "wide"
)

# Name tables Source <> KPI <> Gran
dbWriteTable(con, 
             DBI::Id(schema = "staging", table = "acs_migration_state"),
             state_acs_raw, 
             overwrite = TRUE)

# County ----
county_acs_raw <- acs_ingest(
  geography = "county",
  years     = 2012:2023,
  variables = vars,
  survey    = "acs5",
  output    = "wide"
)

# Name tables Source <> KPI <> Gran
dbWriteTable(con, 
             DBI::Id(schema = "staging", table = "acs_migration_county"),
             county_acs_raw, 
             overwrite = TRUE)

# ZCTA ----
zcta_acs_raw <- acs_ingest(
  geography = "zcta",
  years     = 2012:2023,
  variables = vars,
  survey    = "acs5",
  output    = "wide"
)

# Name tables Source <> KPI <> Gran
dbWriteTable(con, 
             DBI::Id(schema = "staging", table = "acs_migration_zcta"),
             zcta_acs_raw, 
             overwrite = TRUE)

# Place ----
place_acs_raw <- acs_ingest(
  geography = "place",
  years     = 2012:2023,
  variables = vars,
  survey    = "acs5",
  output    = "wide"
)

# Name tables Source <> KPI <> Gran
dbWriteTable(con, 
             DBI::Id(schema = "staging", table = "acs_migration_place"),
             place_acs_raw, 
             overwrite = TRUE)

# Tract ----
# FL
tract_fl_acs_raw <- acs_ingest(
  geography = "tract",
  state = 'FL',
  years     = 2012:2023,
  variables = vars,
  survey    = "acs5",
  output    = "wide"
)

# Name tables Source <> KPI <> Gran
dbWriteTable(con, 
             DBI::Id(schema = "staging", table = "acs_migration_tract_fl"),
             tract_fl_acs_raw, 
             overwrite = TRUE)

# NC
tract_nc_acs_raw <- acs_ingest(
  geography = "tract",
  state = 'NC',
  years     = 2012:2023,
  variables = vars,
  survey    = "acs5",
  output    = "wide"
)

# Name tables Source <> KPI <> Gran
dbWriteTable(con, 
             DBI::Id(schema = "staging", table = "acs_migration_tract_nc"),
             tract_nc_acs_raw, 
             overwrite = TRUE)

# GA
tract_ga_acs_raw <- acs_ingest(
  geography = "tract",
  state = 'GA',
  years     = 2012:2023,
  variables = vars,
  survey    = "acs5",
  output    = "wide"
)

# Name tables Source <> KPI <> Gran
dbWriteTable(con, 
             DBI::Id(schema = "staging", table = "acs_migration_tract_ga"),
             tract_ga_acs_raw, 
             overwrite = TRUE)

dbDisconnect(con, shutdown = TRUE)