suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
  library(glue)
  library(sf)
})

ROF_DUCKDB_SCHEMAS <- c(
  "raw_ext",
  "ref",
  "foundation",
  "scoring",
  "zones",
  "parcel",
  "serving",
  "qa"
)

rof_schema_table <- function(schema_name, table_name) {
  DBI::Id(schema = schema_name, table = table_name)
}

ensure_rof_duckdb_schemas <- function(con, schemas = ROF_DUCKDB_SCHEMAS) {
  invisible(lapply(schemas, function(schema_name) {
    DBI::dbExecute(con, glue("CREATE SCHEMA IF NOT EXISTS {DBI::dbQuoteIdentifier(con, schema_name)};"))
  }))
}

format_state_scope <- function(profile = get_market_profile()) {
  paste(get_market_state_scope(profile), collapse = ",")
}

build_market_metadata <- function(profile = get_market_profile(), build_source = NA_character_) {
  tibble::tibble(
    market_key = profile$market_key,
    cbsa_code = profile$cbsa_code,
    state_scope = format_state_scope(profile),
    build_source = build_source,
    run_timestamp = as.character(Sys.time())
  )
}

prepend_market_metadata <- function(df, profile = get_market_profile(), build_source = NA_character_) {
  metadata <- build_market_metadata(profile, build_source)
  metadata <- metadata[, setdiff(names(metadata), names(df)), drop = FALSE]
  bind_cols(metadata, df)
}

sf_to_geometry_wkt_table <- function(sf_obj, geometry_col = attr(sf_obj, "sf_column")) {
  sf_col <- if (!is.null(geometry_col) && nzchar(geometry_col)) geometry_col else attr(sf_obj, "sf_column")
  geom <- sf::st_geometry(sf_obj)
  out <- sf_obj %>%
    sf::st_drop_geometry() %>%
    mutate(geom_wkt = sf::st_as_text(geom))

  if (!is.null(sf_col) && sf_col %in% names(out)) {
    out[[sf_col]] <- NULL
  }

  out
}

geometry_wkt_table_to_sf <- function(df, crs = GEOMETRY_ASSUMPTIONS$expected_crs_epsg) {
  if (!"geom_wkt" %in% names(df)) {
    stop("Expected geom_wkt column for geometry reconstruction.", call. = FALSE)
  }

  sf::st_as_sf(df, wkt = "geom_wkt", crs = crs)
}

write_duckdb_table <- function(con, schema_name, table_name, df, overwrite = TRUE) {
  ensure_rof_duckdb_schemas(con)
  DBI::dbWriteTable(
    con,
    rof_schema_table(schema_name, table_name),
    df,
    overwrite = overwrite,
    temporary = FALSE
  )
}

duckdb_table_exists <- function(con, schema_name, table_name) {
  DBI::dbExistsTable(con, rof_schema_table(schema_name, table_name))
}
