# Create Benchmarks for Overview Section

# Load Packages ----
# In the future we should update this to read from a requirements file
library(tidyverse)
library(janitor)
library(readr)
library(lubridate)
library(glue)
library(scales)
library(sf)
library(tigris)
library(stringr)
library(fmsb)
library(patchwork)

# Set Paths & Params ----
# Target CBSA
metro_name <- "Wilmington, NC"      # Flexible lookup by title
target_geoid <- "48900"

# Analysis window (use a window that overlaps your sources)
analysis_years <- 2013:2023

# Benchmark definition: Census Divisions we consider "Southeast"
se_divisions <- c("South Atlantic","East South Central","West South Central")

# Benchmark method: "metro_mean" (simple mean) or "pop_weighted"
benchmark_method <- "metro_mean"

# Make sure we're reading from the project Renviron
if (file.exists(".Renviron")) readRenviron(".Renviron")

# Set up path based on Renviron
get_env_path <- function(key) {
  val <- Sys.getenv(key, unset = "")
  if (!nzchar(val)) return(NA_character_)
  path.expand(val)
}

# Expected keys in your .Renviron (project or user):
# SILVER_CBSA, SILVER_COUNTY, GOLD_XWALK, GOLD_CBSA
silver_cbsa_env <- get_env_path("SILVER_CBSA")
silver_county_env <- get_env_path("SILVER_COUNTY")
gold_xwalk_env <- get_env_path("GOLD_XWALK")
gold_cbsa_env <- get_env_path("GOLD_CBSA")
gold_county_env <- get_env_path("GOLD_COUNTY")
gold_deep_dive_env <- get_env_path("GOLD_DEEP_DIVE")
analytics_env <- get_env_path("ANALYTICS")
benchmark_env <- get_env_path("ANALYTICS_BENCHMARKS")

# Ingest Long and Snapshot Data ----
cbsa_const_long <- readr::read_csv(file.path(gold_deep_dive_env, "overview_cbsa_constant_long.csv"), show_col_types = FALSE) %>%
  janitor::clean_names() 

cbsa_const_snap <- readr::read_csv(file.path(gold_deep_dive_env, "overview_cbsa_constant_latest.csv"), show_col_types = FALSE) %>%
  janitor::clean_names()

# Split data into relevant benchmarks ----
wilm_row <- cbsa_const_snap %>% filter(cbsa_geoid == target_geoid)
if (nrow(wilm_row) == 0) stop("cbsa_geoid not found in cbsa_metrics. Set the correct GEOID.")

# Define benchmark groups:
# 1) NC Metros (same state)
bench_nc <- cbsa_const_snap %>% 
  filter(primary_state == wilm_row$primary_state[1],
         cbsa_type == "Metro Area")

# 2) Southeast Metros (by Census Divisions)
bench_se <- cbsa_const_snap %>% 
  filter(division %in% se_divisions,
         cbsa_type == "Metro Area")

# 3) US Metros (all)
bench_us <- cbsa_const_snap %>%
  filter(cbsa_type == "Metro Area",
         region != "-")

# Create Benchmark DFs
bm_nc <- bench_summary(bench_nc, benchmark_method)
bm_se <- bench_summary(bench_se, benchmark_method)
bm_us <- bench_summary(bench_us, benchmark_method)

# Let's write our Benchmarks to the new folder
write_csv(bm_nc, paste0(benchmark_env, "/bm_nc.csv"))
write_csv(bm_se, paste0(benchmark_env, "/bm_se.csv"))
write_csv(bm_us, paste0(benchmark_env, "/bm_us.csv"))



# Let's then create a script that makes sure we have all of our data for the visual libraries
  # Benchmarks
  # Long Series
  # Constants

# Let's also figure out how we can create a requirements section 
# that makes sure all packages and user functions are created at the start