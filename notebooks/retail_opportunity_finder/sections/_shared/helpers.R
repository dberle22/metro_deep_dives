# Shared helper functions for Retail Opportunity Finder section modules

suppressPackageStartupMessages({
  library(dplyr)
  library(glue)
})

resolve_project_root <- function() {
  project <- get_env_path("METRO")
  if (is.na(project) || !nzchar(project)) {
    project <- normalizePath(".", winslash = "/", mustWork = TRUE)
  }
  project
}

resolve_duckdb_path <- function() {
  data_root <- get_env_path("DATA")
  if (is.na(data_root) || !nzchar(data_root)) {
    stop("Environment variable DATA is required to resolve DuckDB path.", call. = FALSE)
  }
  file.path(data_root, "duckdb", "metro_deep_dive.duckdb")
}

connect_project_duckdb <- function(read_only = TRUE) {
  db_path <- resolve_duckdb_path()
  if (!file.exists(db_path)) {
    stop(glue("DuckDB file not found: {db_path}"), call. = FALSE)
  }
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = read_only)
  DBI::dbExecute(con, "LOAD spatial;")
  con
}

read_sql_file <- function(path) {
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

query_df_sql_file <- function(con, sql_path) {
  sql <- read_sql_file(sql_path)
  DBI::dbGetQuery(con, sql)
}

assert_required_columns <- function(df, required, df_name = "data.frame") {
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(glue("{df_name} missing required columns: {paste(missing, collapse = ', ')}"), call. = FALSE)
  }
  invisible(TRUE)
}

validate_columns <- function(df, required, df_name = "data.frame") {
  missing <- setdiff(required, names(df))
  list(
    dataset = df_name,
    n_rows = nrow(df),
    n_cols = ncol(df),
    missing_columns = missing,
    missing_count = length(missing),
    pass = length(missing) == 0
  )
}

validate_unique_key <- function(df, key_col, df_name = "data.frame") {
  if (!key_col %in% names(df)) {
    return(list(dataset = df_name, key = key_col, pass = FALSE, issue = "missing_key_column"))
  }
  n <- nrow(df)
  n_distinct <- dplyr::n_distinct(df[[key_col]])
  list(
    dataset = df_name,
    key = key_col,
    n_rows = n,
    n_distinct = n_distinct,
    duplicates = n - n_distinct,
    pass = n == n_distinct
  )
}

null_rate_summary <- function(df, cols, df_name = "data.frame") {
  cols <- intersect(cols, names(df))
  if (length(cols) == 0) {
    return(data.frame(dataset = character(), column = character(), null_rate = numeric()))
  }
  out <- lapply(cols, function(col) {
    data.frame(
      dataset = df_name,
      column = col,
      null_rate = mean(is.na(df[[col]])),
      stringsAsFactors = FALSE
    )
  })
  dplyr::bind_rows(out)
}

validate_sf <- function(sf_obj, name = "sf_object", expected_epsg = 4326) {
  is_sf <- inherits(sf_obj, "sf")
  n <- if (is_sf) nrow(sf_obj) else NA_integer_
  crs <- if (is_sf) sf::st_crs(sf_obj)$epsg else NA_integer_
  n_empty <- if (is_sf) sum(sf::st_is_empty(sf_obj)) else NA_integer_
  validity <- if (is_sf) sf::st_is_valid(sf_obj) else NA
  invalid <- if (is_sf) sum(!validity, na.rm = TRUE) else NA_integer_

  list(
    dataset = name,
    is_sf = is_sf,
    n_rows = n,
    crs_epsg = crs,
    empty_geometries = n_empty,
    invalid_geometries = invalid,
    pass = is_sf &&
      !is.na(n) && n > 0 &&
      !is.na(crs) && crs == expected_epsg &&
      !is.na(n_empty) && n_empty == 0 &&
      !is.na(invalid) && invalid == 0
  )
}

zscore <- function(x) {
  s <- stats::sd(x, na.rm = TRUE)
  if (is.na(s) || s == 0) return(rep(0, length(x)))
  (x - mean(x, na.rm = TRUE)) / s
}

pct_rank <- function(x) {
  dplyr::percent_rank(x)
}

run_metadata <- function() {
  git_hash <- tryCatch(
    system("git rev-parse --short HEAD", intern = TRUE),
    error = function(e) NA_character_
  )
  if (length(git_hash) == 0) git_hash <- NA_character_

  list(
    run_timestamp = as.character(Sys.time()),
    r_version = as.character(getRversion()),
    git_hash = git_hash,
    target_cbsa = if (exists("TARGET_CBSA")) TARGET_CBSA else NA_character_,
    target_vintage = if (exists("TARGET_VINTAGE")) TARGET_VINTAGE else NA_character_,
    baseline_vintage = if (exists("BASELINE_VINTAGE")) BASELINE_VINTAGE else NA_character_,
    target_year = if (exists("TARGET_YEAR")) TARGET_YEAR else NA_integer_
  )
}

validate_model_params <- function(model_params) {
  required_weights <- c("growth", "units", "headroom", "price", "commute")
  has_weights <- all(required_weights %in% names(model_params$weights))
  weight_sum <- sum(model_params$weights[required_weights])

  list(
    has_required_weights = has_weights,
    weights_sum_to_one = isTRUE(all.equal(weight_sum, 1, tolerance = 1e-9)),
    weight_sum = weight_sum,
    pass = has_weights && isTRUE(all.equal(weight_sum, 1, tolerance = 1e-9))
  )
}

save_artifact <- function(obj, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(obj, path)
}
