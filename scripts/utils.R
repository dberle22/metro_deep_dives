# Load Packages and Functions for the section

# Packages ----
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
library(viridis)
library(ggrepel)
library(tidycensus)
library(readxl)
library(bea.R)
library(here)

# Reproducibility ----
set.seed(42)

# Set the Working Directory

# Load Functions from R Scripts
source(here::here("R", "add_growth_cols.R"))
source(here::here("R", "benchmark_summary.R"))
source(here::here("R", "generic_functions.R"))
source(here::here("R", "rebase_cbsa_from_counties.R"))
source(here::here("R", "acs_ingest.R"))
source(here::here("R", "standardize_acs_df.R"))

# Make sure we're reading from the project Renviron
if (file.exists(".Renviron")) readRenviron(".Renviron")