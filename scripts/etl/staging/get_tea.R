# In this script we get our TEA Raw Data

# Find our current directory 
getwd()

# Set up our environment ----
# Read our common libraries & set other packages
source(here::here("scripts", "utils.R"))


# Set paths for our environments
# Make sure we're reading from the project Renviron
if (file.exists(".Renviron")) readRenviron(".Renviron")

# Set our Paths - Pointing to our Bronze folder in Data
bronze <- get_env_path("DATA_RAW")
data <- get_env_path("DATA")
db_path <- paste0(data, "/duckdb", "/metro_deep_dive.duckdb")

# Connect to the DB ----
con <- dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = FALSE)

# Ingest Budget Data ----
## Raw Data ----
tea_budget_2025 <- read_csv(paste0(bronze, "/tea/tea_budget2025.csv"))

## Metadata ----
### Function ----
meta_tea_budget_function_raw <- read_delim(
  file = paste0(bronze, "/tea/budget2025d/FUNCTION_2025F.TXT"),
  delim = ",",
  col_names = FALSE,
  col_types = cols(.default = col_character()),
  trim_ws = TRUE
)

meta_tea_budget_function <- meta_tea_budget_function_raw %>%
  setNames(c(
    "function_code",
    "function_desc",
    "function_desc_long",
    "payroll_elig",
    "budget_elig",
    "actual_elig",
    "dtupdate"
  )) %>%
  mutate(
    function_code = str_pad(function_code, 2, pad = "0"),
    dtupdate = suppressWarnings(as.numeric(dtupdate))
  )

### FUND ----
meta_tea_budget_fund_raw <- read_delim(
  file = paste0(bronze, "/tea/budget2025d/FUND_2025F.TXT"),
  delim = ",",
  col_names = FALSE,
  col_types = cols(.default = col_character()),
  trim_ws = TRUE
)

meta_tea_budget_fund <- meta_tea_budget_fund_raw %>%
  setNames(c(
    "fund_code",
    "fund_desc",
    "fund_desc_long",
    "payroll_elig",
    "budget_elig",
    "actual_elig",
    "ssa_actual_elig",
    "dtupdate"
  )) %>%
  mutate(
    fund_code = str_pad(fund_code, 3, pad = "0"),
    dtupdate = suppressWarnings(as.numeric(dtupdate))
  )


### OBJECT ----
meta_tea_budget_object_raw <- read_delim(
  file = paste0(bronze, "/tea/budget2025d/OBJECT_2025F.TXT"),
  delim = ",",
  col_names = FALSE,
  col_types = cols(.default = col_character()),
  trim_ws = TRUE
)

meta_tea_budget_object <- meta_tea_budget_object_raw %>%
  setNames(c(
    "object_code",
    "object_desc",
    "object_desc_long",
    "payroll_elig",
    "budget_elig",
    "actual_elig",
    "dtupdate"
  )) %>%
  mutate(
    object_code = str_pad(object_code, 4, pad = "0"),
    dtupdate = suppressWarnings(as.numeric(dtupdate))
  )


## District Master ----
tea_district_master_2025 <- read_csv(paste0(bronze, "/tea/tea_district_school_master.csv"))

