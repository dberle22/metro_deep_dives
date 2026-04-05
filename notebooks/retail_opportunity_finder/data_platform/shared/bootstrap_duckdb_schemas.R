source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

platform_helpers_path <- "notebooks/retail_opportunity_finder/data_platform/shared/platform_helpers.R"
if (!file.exists(platform_helpers_path)) {
  stop("Missing data platform helper file.", call. = FALSE)
}
source(platform_helpers_path)

bootstrap_rof_duckdb_schemas <- function() {
  con <- connect_project_duckdb(read_only = FALSE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  ensure_rof_duckdb_schemas(con)

  invisible(ROF_DUCKDB_SCHEMAS)
}

if (identical(environment(), globalenv())) {
  created <- bootstrap_rof_duckdb_schemas()
  message("ROF DuckDB schema bootstrap complete: ", paste(created, collapse = ", "))
}
