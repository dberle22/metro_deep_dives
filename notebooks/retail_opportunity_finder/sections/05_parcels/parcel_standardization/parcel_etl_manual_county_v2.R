# Parcel ETL manual county workflow v2
# Purpose: run one county step by step in RStudio with explicit, inspectable blocks.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(sf)
  library(DBI)
  library(duckdb)
})

## Small helpers ---------------------------------------------------------------

normalize_join_key <- function(x) {
  x %>%
    as.character() %>%
    stringr::str_trim() %>%
    dplyr::na_if("") %>%
    stringr::str_to_upper()
}

clean_names_simple <- function(x) {
  x %>%
    stringr::str_trim() %>%
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") %>%
    stringr::str_replace_all("(^_+|_+$)", "") %>%
    stringr::str_to_lower()
}

coalesce_first_existing <- function(df, candidates) {
  found <- intersect(candidates, names(df))
  if (length(found) == 0) {
    return(rep(NA_character_, nrow(df)))
  }

  out <- as.character(df[[found[[1]]]])
  if (length(found) > 1) {
    for (nm in found[-1]) {
      out <- dplyr::coalesce(out, as.character(df[[nm]]))
    }
  }

  out
}

## 1. Simple Config ------------------------------------------------------------

# Edit only this block for a county run.
# Sections 2-3 can be run without geometry.
# Sections 4-6 can be rerun after tabular_clean exists in memory.
# Section 7 should be run only after Section 6 looks correct.

# Example manual fill-in:
# state <- "FL"
# county_name <- "Alachua County"
# county_tag <- "alachua_fl"
# tabular_path <- "/absolute/path/to/parcel_tabular.csv"
# geom_path <- "/absolute/path/to/parcel_geom.shp"
# duckdb_path <- "~/projects/data/duckdb/metro_deep_dive.duckdb"
# parcel_geom_root <- "~/projects/data/property_taxes/parcel_geom"
# parcel_duckdb_schema <- "rof_parcel"
# repair_invalid_geom <- FALSE

state <- "FL"
county_name <- ""
county_tag <- ""
tabular_path <- ""
geom_path <- ""
duckdb_path <- "~/projects/data/duckdb/metro_deep_dive.duckdb"
parcel_geom_root <- "~/projects/data/property_taxes/parcel_geom"
parcel_duckdb_schema <- "rof_parcel"
repair_invalid_geom <- FALSE

parcel_geom_state_dir <- file.path(parcel_geom_root, tolower(state))
parcel_geom_qa_dir <- file.path(parcel_geom_state_dir, "qa")
county_geom_rds_path <- file.path(parcel_geom_state_dir, paste0(county_tag, "_geom.rds"))
county_join_qa_rds_path <- file.path(parcel_geom_qa_dir, paste0(county_tag, "_join_qa.rds"))
county_join_qa_csv_path <- file.path(parcel_geom_qa_dir, paste0(county_tag, "_join_qa_unmatched.csv"))

## 2. Read in Tabular and clean data -------------------------------------------

stopifnot(nzchar(tabular_path))

tabular_ext <- tolower(tools::file_ext(tabular_path))

if (tabular_ext == "csv") {
  tabular_raw <- readr::read_csv(
    tabular_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
} else if (tabular_ext == "rds") {
  tabular_raw <- readRDS(tabular_path)
  tabular_raw <- tibble::as_tibble(tabular_raw)
} else {
  stop("tabular_path must point to a .csv or .rds file.", call. = FALSE)
}

names(tabular_raw) <- clean_names_simple(names(tabular_raw))
tabular_raw <- tabular_raw[, !duplicated(names(tabular_raw)), drop = FALSE]

tabular_clean <- tabular_raw %>%
  transmute(
    state = state,
    county_name = county_name,
    county_tag = county_tag,
    source_file = basename(tabular_path),
    parcel_id = coalesce_first_existing(., c("parcel_id", "parcelid", "parid")),
    alt_key = coalesce_first_existing(., c("alt_key", "altkey", "alternate_id")),
    county_code = coalesce_first_existing(., c("co_no", "county", "county_code")),
    county_fips = coalesce_first_existing(., c("county_fips", "cnty_fips")),
    use_code = coalesce_first_existing(., c("dor_uc", "pa_uc", "use_code")),
    owner_name = coalesce_first_existing(., c("own_name", "owner_name")),
    owner_addr = coalesce_first_existing(., c("own_addr1", "owner_addr")),
    phys_addr = coalesce_first_existing(., c("phy_addr1", "phys_addr", "site_address")),
    just_value = readr::parse_number(coalesce_first_existing(., c("jv"))),
    land_value = readr::parse_number(coalesce_first_existing(., c("lnd_val", "land_value"))),
    impro_value = readr::parse_number(coalesce_first_existing(., c("nconst_val", "impro_value"))),
    total_value = readr::parse_number(coalesce_first_existing(., c("del_val", "total_value"))),
    living_area_sqft = readr::parse_number(coalesce_first_existing(., c("tot_lvg_area", "living_area_sqft"))),
    sale_qual_code = coalesce_first_existing(., c("qual_cd1", "qual_cd2", "sale_qual_code", "sale_qual1")),
    sale_price1 = readr::parse_number(coalesce_first_existing(., c("sale_prc1", "sale_price1"))),
    sale_yr1 = suppressWarnings(as.integer(coalesce_first_existing(., c("sale_yr1", "sale_year1")))),
    sale_mo1 = suppressWarnings(as.integer(coalesce_first_existing(., c("sale_mo1", "sale_month1")))),
    join_key = dplyr::coalesce(parcel_id, alt_key),
    join_key = normalize_join_key(join_key),
    parcel_id = normalize_join_key(parcel_id),
    alt_key = normalize_join_key(alt_key),
    county_code = stringr::str_trim(as.character(county_code)),
    county_fips = stringr::str_trim(as.character(county_fips)),
    use_code = stringr::str_trim(as.character(use_code)),
    sale_qual_code = stringr::str_pad(stringr::str_trim(as.character(sale_qual_code)), width = 2, side = "left", pad = "0")
  )

tabular_clean <- bind_rows(
  tabular_clean %>% filter(is.na(join_key) | join_key == ""),
  tabular_clean %>%
    filter(!is.na(join_key) & join_key != "") %>%
    distinct(join_key, .keep_all = TRUE)
)

# Quick inspection before Section 3:
nrow(tabular_clean)
names(tabular_clean)
tabular_clean %>% summarise(join_key_missing = sum(is.na(join_key) | join_key == ""))

## 3. Write Tabular to DuckDB --------------------------------------------------

# This block is independent. Run it before any geometry work if you want to
# validate the cleaned tabular payload first. It replaces one county at a time.
# Disconnect DuckDB at the end.

stopifnot(nzchar(duckdb_path))

dir.create(dirname(duckdb_path), recursive = TRUE, showWarnings = FALSE)
con <- DBI::dbConnect(duckdb::duckdb(), dbdir = duckdb_path, read_only = FALSE)
DBI::dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", parcel_duckdb_schema, ";"))

tabular_table_id <- DBI::Id(schema = parcel_duckdb_schema, table = "parcel_tabular_clean")

if (!DBI::dbExistsTable(con, tabular_table_id)) {
  DBI::dbWriteTable(
    con,
    tabular_table_id,
    tabular_clean,
    overwrite = TRUE
  )
} else {
  DBI::dbExecute(
    con,
    paste0(
      "DELETE FROM ", parcel_duckdb_schema, ".parcel_tabular_clean ",
      "WHERE county_tag = ", DBI::dbQuoteString(con, county_tag)
    )
  )
  DBI::dbWriteTable(
    con,
    tabular_table_id,
    tabular_clean,
    append = TRUE
  )
}

DBI::dbDisconnect(con, shutdown = TRUE)

## 4. Read in Geom and trim columns --------------------------------------------

# This block keeps one lean geometry object with duplicates preserved.
# Use it for spatial analysis, plotting, and join testing.

stopifnot(nzchar(geom_path))

geom_raw <- sf::st_read(geom_path, quiet = TRUE)
names(geom_raw) <- clean_names_simple(names(geom_raw))
geom_raw <- geom_raw[, !duplicated(names(geom_raw)), drop = FALSE]

geom_raw <- tryCatch(
  sf::st_zm(geom_raw, drop = TRUE, what = "ZM"),
  error = function(e) geom_raw
)

if (isTRUE(repair_invalid_geom)) {
  geom_raw <- tryCatch(
    sf::st_make_valid(geom_raw),
    error = function(e) geom_raw
  )
}

geom_trimmed <- geom_raw %>%
  transmute(
    state = state,
    county_name = county_name,
    county_tag = county_tag,
    source_shp = basename(geom_path),
    parcel_id = coalesce_first_existing(., c("parcel_id", "parcelid", "parid")),
    alt_key = coalesce_first_existing(., c("alt_key", "altkey", "alternate_id")),
    county_code = coalesce_first_existing(., c("co_no", "county", "county_code")),
    county_fips = coalesce_first_existing(., c("county_fips", "cnty_fips")),
    join_key = dplyr::coalesce(parcel_id, alt_key),
    join_key = normalize_join_key(join_key),
    parcel_id = normalize_join_key(parcel_id),
    alt_key = normalize_join_key(alt_key),
    county_code = stringr::str_trim(as.character(county_code)),
    county_fips = stringr::str_trim(as.character(county_fips)),
    geometry = geometry
  )

geom_key_profile <- geom_trimmed %>%
  sf::st_drop_geometry() %>%
  mutate(has_join_key = !is.na(join_key) & join_key != "") %>%
  filter(has_join_key) %>%
  count(join_key, name = "row_count")

geom_duplicate_profile <- tibble::tibble(
  total_rows = nrow(geom_trimmed),
  unique_join_keys = geom_trimmed %>%
    sf::st_drop_geometry() %>%
    filter(!is.na(join_key) & join_key != "") %>%
    summarise(n = n_distinct(join_key)) %>%
    pull(n),
  duplicate_group_count = sum(geom_key_profile$row_count > 1),
  rows_in_duplicate_groups = sum(geom_key_profile$row_count[geom_key_profile$row_count > 1])
)

# Quick inspection before Section 5:
# - review geom_duplicate_profile
# - inspect the largest duplicate groups
# - confirm join_key derivation looks right for this county

geom_duplicate_profile
geom_key_profile %>%
  filter(row_count > 1) %>%
  arrange(desc(row_count)) %>%
  head(20)

## 5. Write Geom to County RDS -------------------------------------------------

# Write one county geometry file under parcel_geom/<state>.
# This is the main geometry artifact for spatial work and plotting.

stopifnot(nzchar(parcel_geom_root))

dir.create(parcel_geom_state_dir, recursive = TRUE, showWarnings = FALSE)
saveRDS(geom_trimmed, county_geom_rds_path)

## 6. Join Tabular to Geom and Test Join ---------------------------------------

tabular_join_cols <- tabular_clean %>%
  select(
    join_key,
    source_file,
    use_code,
    sale_qual_code,
    owner_name,
    owner_addr,
    phys_addr,
    just_value,
    land_value,
    impro_value,
    total_value,
    living_area_sqft,
    sale_price1,
    sale_yr1,
    sale_mo1
  )

parcel_geom_joined <- geom_trimmed %>%
  left_join(tabular_join_cols, by = "join_key") %>%
  select(
    state,
    county_name,
    county_tag,
    source_shp,
    source_file,
    join_key,
    parcel_id,
    alt_key,
    county_code,
    county_fips,
    use_code,
    sale_qual_code,
    owner_name,
    owner_addr,
    phys_addr,
    just_value,
    land_value,
    impro_value,
    total_value,
    living_area_sqft,
    sale_price1,
    sale_yr1,
    sale_mo1,
    geometry
  )

join_qa <- parcel_geom_joined %>%
  sf::st_drop_geometry() %>%
  summarise(
    total_joined_rows = n(),
    unmatched_rows = sum(is.na(source_file)),
    unmatched_rate = unmatched_rows / total_joined_rows,
    duplicate_geometry_key_count = sum(duplicated(join_key[!is.na(join_key) & join_key != ""]))
  )

duplicate_join_key_groups <- parcel_geom_joined %>%
  sf::st_drop_geometry() %>%
  filter(!is.na(join_key) & join_key != "") %>%
  count(join_key, sort = TRUE) %>%
  filter(n > 1) %>%
  head(20)

unmatched_sample <- parcel_geom_joined %>%
  filter(is.na(source_file)) %>%
  sf::st_drop_geometry() %>%
  select(join_key, parcel_id, alt_key, county_code) %>%
  head(20)

# Inspect before Section 7:
# - join_qa unmatched_rate should be acceptable for this county
# - duplicate_geometry_key_count will reflect source geometry duplicates
# - duplicate_join_key_groups shows the biggest duplicate geometry groups
# - unmatched_sample should look explainable before writing DuckDB tables

join_qa
duplicate_join_key_groups
unmatched_sample

## 7. Write County Join QA -----------------------------------------------------

# Run this only after Section 6 looks correct.
# This writes a local county QA artifact next to the county geometry RDS.

dir.create(parcel_geom_qa_dir, recursive = TRUE, showWarnings = FALSE)

county_join_qa <- join_qa %>%
  mutate(
    state = state,
    county_name = county_name,
    county_tag = county_tag
  )

county_join_qa_artifact <- list(
  join_qa = county_join_qa,
  duplicate_join_key_groups = duplicate_join_key_groups,
  unmatched_sample = unmatched_sample
)

saveRDS(county_join_qa_artifact, county_join_qa_rds_path)
readr::write_csv(unmatched_sample, county_join_qa_csv_path, na = "")
