source("notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization/00_config.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(DBI)
  library(duckdb)
  library(sf)
  library(glue)
})

publish_parcels_to_duckdb <- function() {
  paths <- parcel_standardization_paths()

  if (!nzchar(paths$duckdb_path)) {
    stop(
      "DuckDB path not configured. Set PARCEL_DUCKDB_PATH or DATA environment variable.",
      call. = FALSE
    )
  }

  if (!file.exists(paths$standardized_attr_rds)) {
    stop("Missing standardized attribute artifact. Run script 01 before publishing.", call. = FALSE)
  }

  attrs <- readRDS(paths$standardized_attr_rds)
  geoms <- NULL
  if (file.exists(paths$standardized_geom_analysis_rds)) {
    geoms <- readRDS(paths$standardized_geom_analysis_rds)
  } else {
    county_files <- list.files(
      file.path(paths$standardized_root, "county_outputs"),
      pattern = "parcel_geometries_analysis\\.rds$",
      full.names = TRUE,
      recursive = TRUE
    )
    if (length(county_files) == 0) {
      stop("Missing standardized geometry artifacts. Run script 02 before publishing.", call. = FALSE)
    }
    geoms <- dplyr::bind_rows(lapply(county_files, readRDS))
  }

  dir.create(dirname(paths$duckdb_path), recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = paths$duckdb_path, read_only = FALSE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, "LOAD spatial;")

  DBI::dbWriteTable(con, "parcel_attributes_standardized", attrs, overwrite = TRUE)

  # Persist geometry through WKT for a stable SQL-side reconstruction.
  geoms_wkt <- geoms
  geoms_wkt$geometry_wkt <- sf::st_as_text(sf::st_geometry(geoms_wkt))
  sf::st_geometry(geoms_wkt) <- NULL
  DBI::dbWriteTable(con, "parcel_geometries_standardized", geoms_wkt, overwrite = TRUE)

  message(glue("Published parcel tables to DuckDB: {paths$duckdb_path}"))
  invisible(TRUE)
}

if (identical(environment(), globalenv())) {
  publish_parcels_to_duckdb()
}
