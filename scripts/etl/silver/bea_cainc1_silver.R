# In this script we normalize BEA CAINC1 data into our Silver layer

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

county_cainc1_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_county_cainc1")
cbsa_cainc1_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_cbsa_cainc1")
state_cainc1_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_state_cainc1")

## Reference Tables ----
line_codes_ref <- dbGetQuery(con, "SELECT * FROM silver.bea_regional_metrics_ref")

state_test <- state_cainc1_stage %>%
  filter(line_code == "3")


# 3. Standardize Value Names ----
# Column names are already standard and value columns are multiplied

## Create Long Data Set ----
# Union together tables, add Line Code Names from 
# Clean up the value names using the Line Code Names from our Ref table

# Union data frames together
cainc1_stage_all <- bind_rows(
  cbsa_cainc1_stage,
  county_cainc1_stage,
  state_cainc1_stage
) %>%
  mutate(line_code = as.character(line_code))

# Keep only CAINC1 from Line Codes
line_codes_cainc1 <- line_codes_ref %>%
  filter(table == "CAINC1") %>%
  select(table, line_code, metric_key, line_desc_clean)

# Join on line_code (and table, if present)
cainc1_long <- cainc1_stage_all %>%
  left_join(line_codes_cainc1,
            by = c("table" = "table", "line_code" = "line_code"))

## Create the Wide data set ----
cainc1_wide <- cainc1_long %>%
  select(geo_level, geo_id, geo_name, period, table, metric_key, value) %>%
  pivot_wider(
    names_from  = metric_key,   # pi_total, pi_per_capita, population
    values_from = value
  )

## Write data frames to our database ----
DBI::dbWriteTable(con, DBI::Id(schema="silver", table="bea_regional_cainc1_long"),
                  cainc1_long, overwrite = TRUE)

DBI::dbWriteTable(con, DBI::Id(schema="silver", table="bea_regional_cainc1_wide"),
                  cainc1_wide, overwrite = TRUE)

# Disconnect our DB ----
dbDisconnect(con, shutdown = TRUE)

# Extras ----

county_cainc4_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_county_cainc4")
cbsa_cainc4_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_cbsa_cainc4")
state_cainc4_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_state_cainc4")

county_cainc4_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_county_cainc4")
cbsa_cainc4_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_cbsa_cainc4")
state_cainc4_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_state_cainc4")

county_cagdp2_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_county_cagdp2")
cbsa_cagdp2_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_cbsa_cagdp2")
state_cagdp2_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_state_cagdp2")

county_cagdp9_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_county_cagdp9")
cbsa_cagdp9_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_cbsa_cagdp9")
state_cagdp9_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_state_cagdp9")

cbsa_marpp_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_cbsa_marpp")
state_marpp_stage <- dbGetQuery(con, "SELECT * FROM staging.bea_regional_state_marpp")

