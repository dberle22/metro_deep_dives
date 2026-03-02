suppressPackageStartupMessages({
  library(dplyr)
  library(glue)
  library(readr)
  library(stringr)
  library(sf)
  library(DBI)
  library(duckdb)
})

parcel_standardization_paths <- function() {
  this_dir <- "notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization"

  property_tax_root <- Sys.getenv("PROPERTY_TAX_ROOT", unset = "")
  property_state <- Sys.getenv("PROPERTY_STATE", unset = "fl")

  default_state_root <- if (nzchar(property_tax_root)) {
    file.path(property_tax_root, property_state)
  } else {
    ""
  }

  fl_data_root <- Sys.getenv("PROPERTY_DATA_ROOT", unset = "")
  if (!nzchar(fl_data_root) && nzchar(default_state_root)) {
    fl_data_root <- file.path(default_state_root, "data")
  }

  fl_metadata_root <- Sys.getenv("PROPERTY_METADATA_ROOT", unset = "")
  if (!nzchar(fl_metadata_root) && nzchar(default_state_root)) {
    fl_metadata_root <- file.path(default_state_root, "docs")
  }

  property_shape_root <- Sys.getenv("PROPERTY_SHAPE_ROOT", unset = "")
  if (!nzchar(property_shape_root)) {
    property_shape_root <- fl_data_root
  }

  standardized_root <- Sys.getenv("PARCEL_STANDARDIZED_ROOT", unset = "")
  if (!nzchar(standardized_root)) {
    standardized_root <- file.path(this_dir, "outputs")
  }

  duckdb_path <- Sys.getenv("PARCEL_DUCKDB_PATH", unset = "")
  if (!nzchar(duckdb_path)) {
    data_root <- Sys.getenv("DATA", unset = "")
    if (nzchar(data_root)) {
      duckdb_path <- file.path(data_root, "duckdb", "metro_deep_dive.duckdb")
    }
  }

  list(
    this_dir = this_dir,
    property_tax_root = property_tax_root,
    property_state = property_state,
    fl_data_root = fl_data_root,
    fl_metadata_root = fl_metadata_root,
    property_shape_root = property_shape_root,
    standardized_root = standardized_root,
    standardized_attr_rds = file.path(standardized_root, "parcel_attributes_standardized.rds"),
    standardized_geom_rds = file.path(standardized_root, "parcel_geometries_standardized.rds"),
    standardized_geom_analysis_rds = file.path(standardized_root, "parcel_geometries_standardized_analysis.rds"),
    standardized_geom_gpkg = file.path(standardized_root, "parcel_geometries_standardized.gpkg"),
    standardized_geom_join_qa_rds = file.path(standardized_root, "parcel_geometry_join_qa.rds"),
    duckdb_path = duckdb_path
  )
}

assert_required_path <- function(path_value, env_name, expected = "directory") {
  if (!nzchar(path_value)) {
    stop(glue("Missing required env var: {env_name}"), call. = FALSE)
  }
  if (expected == "directory" && !dir.exists(path_value)) {
    stop(glue("{env_name} does not exist: {path_value}"), call. = FALSE)
  }
  invisible(TRUE)
}

list_parcel_csvs <- function(data_root) {
  files <- list.files(data_root, pattern = "\\.csv$", full.names = TRUE, recursive = TRUE)
  files <- files[!grepl("fl_parcel_metadata", basename(files), ignore.case = TRUE)]
  files
}

read_metadata_lookup <- function(metadata_root, filename_pattern) {
  candidate <- list.files(
    metadata_root,
    pattern = filename_pattern,
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )

  if (length(candidate) == 0) {
    return(NULL)
  }
  readr::read_csv(candidate[[1]], show_col_types = FALSE)
}

normalize_join_key <- function(x) {
  x %>%
    as.character() %>%
    stringr::str_trim() %>%
    stringr::str_to_upper()
}

message("Parcel standardization config loaded.")
