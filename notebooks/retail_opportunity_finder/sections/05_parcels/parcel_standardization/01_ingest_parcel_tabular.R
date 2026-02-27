source("notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization/00_config.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tidyr)
})

extract_vintage_from_filename <- function(path) {
  name <- tools::file_path_sans_ext(basename(path))
  hit <- stringr::str_extract(name, "\\d{6}$")
  ifelse(is.na(hit), NA_character_, hit)
}

coalesce_first_existing <- function(df, candidates) {
  found <- intersect(candidates, names(df))
  if (length(found) == 0) {
    return(rep(NA_character_, nrow(df)))
  }
  out <- df[[found[[1]]]]
  if (length(found) > 1) {
    for (nm in found[-1]) {
      out <- dplyr::coalesce(out, df[[nm]])
    }
  }
  as.character(out)
}

clean_parcel_tabular <- function(path) {
  raw <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()), show_col_types = FALSE)

  raw %>%
    dplyr::transmute(
      source_file = basename(path),
      vintage = extract_vintage_from_filename(path),
      parcel_id = coalesce_first_existing(raw, c("PARCEL_ID", "parcel_id")),
      alt_key = coalesce_first_existing(raw, c("ALT_KEY", "alt_key")),
      county = coalesce_first_existing(raw, c("CO_NO", "county")),
      twp = coalesce_first_existing(raw, c("TWN", "twp")),
      rng = coalesce_first_existing(raw, c("RNG", "rng")),
      sec = coalesce_first_existing(raw, c("SEC", "sec")),
      census_book = coalesce_first_existing(raw, c("CENSUS_BK", "census_book")),
      use_code = coalesce_first_existing(raw, c("DOR_UC", "USE_CODE", "PA_UC", "use_code")),
      owner_name = coalesce_first_existing(raw, c("OWN_NAME", "owner_name")),
      owner_addr = coalesce_first_existing(raw, c("OWN_ADDR1", "owner_addr")),
      phys_addr = coalesce_first_existing(raw, c("PHY_ADDR1", "phys_addr")),
      land_value = coalesce_first_existing(raw, c("LND_VAL", "land_value")),
      impro_value = coalesce_first_existing(raw, c("NCONST_VAL", "impro_value")),
      total_value = coalesce_first_existing(raw, c("DEL_VAL", "total_value")),
      living_area_sqft = coalesce_first_existing(raw, c("TOT_LVG_AREA", "living_area_sqft")),
      sale_price1 = coalesce_first_existing(raw, c("SALE_PRC1", "sale_price1")),
      sale_yr1 = coalesce_first_existing(raw, c("SALE_YR1", "sale_yr1")),
      sale_mo1 = coalesce_first_existing(raw, c("SALE_MO1", "sale_mo1")),
      sale_price2 = coalesce_first_existing(raw, c("SALE_PRC2", "sale_price2")),
      sale_yr2 = coalesce_first_existing(raw, c("SALE_YR2", "sale_yr2")),
      sale_mo2 = coalesce_first_existing(raw, c("SALE_MO2", "sale_mo2")),
      sale_qual_code = coalesce_first_existing(raw, c("QUAL_CD1", "QUAL_CD2", "SALE_QUAL_CODE", "SALE_QUAL1", "sale_qual_code"))
    ) %>%
    mutate(
      parcel_id = normalize_join_key(parcel_id),
      alt_key = normalize_join_key(alt_key),
      county = str_trim(as.character(county)),
      use_code = str_pad(str_trim(use_code), width = 3, side = "left", pad = "0"),
      sale_qual_code = str_pad(str_trim(sale_qual_code), width = 2, side = "left", pad = "0"),
      across(c(land_value, impro_value, total_value, living_area_sqft, sale_price1, sale_price2), readr::parse_number),
      across(c(sale_yr1, sale_mo1, sale_yr2, sale_mo2), ~ suppressWarnings(as.integer(.x)))
    )
}

join_lookup_tables <- function(parcels, metadata_root) {
  usecode <- read_metadata_lookup(metadata_root, "property_use_code\\.csv$")
  county <- read_metadata_lookup(metadata_root, "county_code\\.csv$")
  salequal <- read_metadata_lookup(metadata_root, "sales_qualification_code\\.csv$")

  out <- parcels

  if (!is.null(usecode)) {
    names(usecode) <- tolower(names(usecode))
    if (all(c("use_code") %in% names(usecode))) {
      usecode <- usecode %>%
        mutate(use_code = str_pad(str_trim(as.character(use_code)), width = 3, side = "left", pad = "0"))
      out <- out %>% left_join(usecode, by = "use_code")
    }
  }

  if (!is.null(county)) {
    names(county) <- tolower(names(county))
    if ("county_number" %in% names(county)) {
      county <- county %>%
        mutate(county_number = str_trim(as.character(county_number)))
      out <- out %>% left_join(county, by = c("county" = "county_number"))
    }
  }

  if (!is.null(salequal)) {
    names(salequal) <- tolower(names(salequal))
    if ("code" %in% names(salequal)) {
      salequal <- salequal %>%
        mutate(code = str_pad(str_trim(as.character(code)), width = 2, side = "left", pad = "0"))
      out <- out %>% left_join(salequal, by = c("sale_qual_code" = "code"))
    }
  }

  out
}

run_parcel_tabular_standardization <- function() {
  paths <- parcel_standardization_paths()
  assert_required_path(paths$property_tax_root, "PROPERTY_TAX_ROOT", expected = "directory")
  assert_required_path(paths$fl_data_root, "PROPERTY_DATA_ROOT or PROPERTY_TAX_ROOT/<state>/data", expected = "directory")
  assert_required_path(paths$fl_metadata_root, "PROPERTY_METADATA_ROOT or PROPERTY_TAX_ROOT/<state>/docs", expected = "directory")

  csv_files <- list_parcel_csvs(paths$fl_data_root)
  if (length(csv_files) == 0) {
    stop(glue("No parcel CSVs found under data root: {paths$fl_data_root}"), call. = FALSE)
  }

  message(glue("Found {length(csv_files)} parcel CSV file(s)."))

  parcels <- bind_rows(lapply(csv_files, clean_parcel_tabular))
  parcels <- join_lookup_tables(parcels, paths$fl_metadata_root)

  dir.create(paths$standardized_root, recursive = TRUE, showWarnings = FALSE)
  saveRDS(parcels, paths$standardized_attr_rds)

  message(glue("Wrote standardized parcel attributes: {paths$standardized_attr_rds}"))
  invisible(parcels)
}

if (identical(environment(), globalenv())) {
  run_parcel_tabular_standardization()
}
