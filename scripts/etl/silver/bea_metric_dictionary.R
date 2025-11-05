# In this script we create a cleaner metric dictionary for BEA

# Find our current directory 
getwd()

# Set up our environment ----
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

# Seed a minimal dictionary from your existing refs and constrain to the tables you use now
dict_seed <-
  dplyr::tbl(con, "silver.bea_regional_line_codes") %>%  # table_name_ref, line_code, line_desc
  dplyr::filter(table_name_ref %in% c("CAINC1","CAINC4","CAGDP2","CAGDP9","MARPP")) %>%
  dplyr::mutate(
    table       = table_name_ref,
    metric_key  = dplyr::case_when(
      table == "CAINC1" & line_code == 1L ~ "pi_total",
      table == "CAINC1" & line_code == 2L ~ "pi_per_capita",
      table == "CAINC1" & line_code == 3L ~ "population",
      table == "CAGDP2" & line_code == 1L ~ "gdp_curr_total",
      table == "CAGDP9" & line_code == 1L ~ "gdp_real2017_total",
      table == "MARPP"  & line_code == 1L ~ "rpp_all_items",
      TRUE ~ stringr::str_to_lower(stringr::str_replace_all(line_desc, "[^A-Za-z0-9]+", "_"))
    ),
    metric_label   = line_desc,
    unit           = NA_character_,            # fill if you want normalized units here
    include_in_wide= dplyr::if_else(table %in% c("CAINC1","CAGDP2","CAGDP9","MARPP") & line_code %in% c(1L,2L,3L), TRUE, FALSE),
    topic          = dplyr::case_when(
      table %in% c("CAINC1","CAINC4") ~ "income",
      table %in% c("CAGDP2","CAGDP9") ~ "gdp",
      table == "MARPP"                ~ "prices",
      TRUE ~ "other"
    ),
    first_vintage  = format(Sys.Date(), "%Y-%m-%d"),
    last_vintage   = NA_character_
  ) %>%
  dplyr::select(table, line_code, metric_key, metric_label, unit, include_in_wide, topic, first_vintage, last_vintage) %>%
  dplyr::distinct() %>%
  dplyr::collect()

DBI::dbExecute(con, "CREATE SCHEMA IF NOT EXISTS ref;")
DBI::dbWriteTable(con, DBI::Id(schema="ref", table="metric_dictionary_bea"), dict_seed, overwrite=TRUE)


# 1) Find “unknown” metrics that hit Stage but aren’t in your dictionary/metadata mapping ----
# List any (table, line_code) combos in Stage not yet mapped to a metric_key for Silver
scan_unknown_metrics <- function(con, stage_table, ref_lines_table = "silver.bea_regional_line_codes",
                                 known_dict_table = "ref.metric_dictionary_bea") {
  stage_pairs <- dplyr::tbl(con, stage_table) %>%
    dplyr::select(table, line_code) %>%
    dplyr::distinct()
  
  ref_lines <- dplyr::tbl(con, ref_lines_table) %>%
    dplyr::select(table_name_ref, line_code, line_desc) %>%
    dplyr::rename(table = table_name_ref)
  
  known <- if (DBI::dbExistsTable(con, DBI::Id(schema="ref", table="metric_dictionary_bea"))) {
    dplyr::tbl(con, known_dict_table) %>% dplyr::select(table, line_code)
  } else {
    dplyr::tibble(table = character(), line_code = integer())
  }
  
  stage_pairs %>%
    dplyr::left_join(ref_lines, by = c("table","line_code")) %>%
    dplyr::anti_join(known, by = c("table","line_code")) %>%
    dplyr::arrange(table, line_code) %>%
    dplyr::collect()
}

# 2) Auto-propose short metric keys from BEA line descriptions ----
# Turn a BEA line_desc into a concise snake_case key (fallback when you don't want to handcraft one)
propose_metric_key <- function(table, line_code, line_desc) {
  base <- gsub("[^A-Za-z0-9]+", "_", tolower(line_desc))
  base <- gsub("^_|_$", "", base)
  paste0(tolower(table), "_", line_code, "_", base)  # deterministic
}

# 3) One-liner to append new rows to your metric dictionary ----
add_to_metric_dictionary <- function(con, new_rows_df) {
  DBI::dbExecute(con, "CREATE SCHEMA IF NOT EXISTS ref;")
  if (!DBI::dbExistsTable(con, DBI::Id(schema="ref", table="metric_dictionary_bea"))) {
    DBI::dbWriteTable(con, DBI::Id(schema="ref", table="metric_dictionary_bea"),
                      new_rows_df, overwrite = TRUE)
  } else {
    DBI::dbWriteTable(con, DBI::Id(schema="ref", table="metric_dictionary_bea"),
                      new_rows_df, append = TRUE)
  }
}

# A quick “add a KPI” working example ----
# 1) Stage a small sample (recent 3 years) to confirm
raw_test <- bea_fetch_regional_lines_geos(
  api_key     = bea_key,
  table_name  = "CAINC4",
  line_codes  = c(10,20,30),
  years       = 2021:2023,
  geofips_vec = "MSA"
)
stage_test <- normalize_bea_regional_stage(raw_test, "cbsa")

# 2) If using a custom dictionary, see what’s unknown
unknown <- scan_unknown_metrics(con, "staging.bea_income_cainc4_cbsa")
# unknown now shows (table, line_code, line_desc) that aren't yet in your dictionary

# 3) Propose keys (or write your own by hand)
if (nrow(unknown)) {
  new_dict <- unknown %>%
    dplyr::mutate(
      metric_key   = mapply(propose_metric_key, table, line_code, line_desc),
      metric_label = line_desc,
      unit         = NA_character_,
      include_in_wide = TRUE,     # or FALSE; your choice
      topic        = "income",
      first_vintage= format(Sys.Date(), "%Y-%m-%d"),
      last_vintage = NA_character_
    ) %>%
    dplyr::select(table, line_code, metric_key, metric_label, unit,
                  include_in_wide, topic, first_vintage, last_vintage)
  add_to_metric_dictionary(con, new_dict)
}