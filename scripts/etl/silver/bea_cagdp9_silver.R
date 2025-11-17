# In this script we normalize BEA CAGDP9 data into our Silver layer

# 1. Set up our Environment
# 2. Read in our Staging Data to R Data Frames
# 3. Standardize our value names
# 4. Union our Data Frames together
# 5. Check for duplicates
# 6. Compute new KPIs and select main columns
# 7. Create Wide and Long versions
# 8. Materialize to Silver

# Find our current directory 
getwd()

# 1. Set up our environment ----
# Read our common libraries & set other packages
source(here::here("scripts", "utils.R"))


# Set paths for our environments
# Make sure we're reading from the project Renviron
if (file.exists(".Renviron")) readRenviron(".Renviron")

# Set our Paths - Pointing to our Bronze folder in Data
bea_key <- get_env_path("BEA_KEY")
data <- get_env_path("DATA")
db_path <- paste0(data, "/duckdb", "/metro_deep_dive.duckdb")

## Connect to the DB ----
con <- dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = FALSE)

# 2. Read in our Staging Data to R Data Frames ----

## Metric Tables ----

county_cagdp9_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_county_cagdp9")
cbsa_cagdp9_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_cbsa_cagdp9")
state_cagdp9_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_state_cagdp9")

## Reference Tables ----
line_codes_ref <- dbGetQuery(con, "SELECT * FROM silver.bea_regional_metrics_ref")

# 3. Standardize Value Names ----
# Column names are already standard and value columns are multiplied

## Create Long Data Set ----
# Union together tables, add Line Code Names from 
# Clean up the value names using the Line Code Names from our Ref table

# Union data frames together
cagdp9_stage_all <- bind_rows(
  cbsa_cagdp9_stage,
  county_cagdp9_stage,
  state_cagdp9_stage
) %>%
  mutate(line_code = as.character(line_code))

# Keep only CAGDP9 from Line Codes
line_codes_cagdp9 <- line_codes_ref %>%
  filter(table == "CAGDP9") %>%
  select(table, line_code, metric_key, line_desc_clean)

# Join on line_code (and table, if present)
cagdp9_long <- cagdp9_stage_all %>%
  left_join(line_codes_cagdp9,
            by = c("table" = "table", "line_code" = "line_code"))

## Create the Wide data set ----
cagdp9_wide <- cagdp9_long %>%
  select(geo_level, geo_id, geo_name, period, table, metric_key, value) %>%
  pivot_wider(
    names_from  = metric_key,   # pi_total, pi_per_capita, population
    values_from = value
  )

## Write data frames to our database ----
DBI::dbWriteTable(con, DBI::Id(schema="silver", table="bea_regional_cagdp9_long"),
                  cagdp9_long, overwrite = TRUE)

DBI::dbWriteTable(con, DBI::Id(schema="silver", table="bea_regional_cagdp9_wide"),
                  cagdp9_wide, overwrite = TRUE)

# Disconnect our DB ----
dbDisconnect(con, shutdown = TRUE)