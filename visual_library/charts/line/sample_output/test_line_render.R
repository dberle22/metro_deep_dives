# Line chart smoke tests backed by DuckDB sample queries.

if (file.exists(".Renviron")) readRenviron(".Renviron")

source("visual_library/shared/standards.R")
source("visual_library/shared/data_contracts.R")
source("visual_library/shared/scatter_query_helpers.R")
source("visual_library/shared/prep_line.R")
source("visual_library/shared/render_line.R")

run_line_tests <- function() {
  sql_path <- "visual_library/charts/line/sample_output/build_line_sample.sql"
  output_dir <- "visual_library/charts/line/sample_output"

  con <- connect_metro_duckdb(read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  df <- DBI::dbGetQuery(con, read_sql_file(sql_path))
  validation <- validate_line_contract(df)
  if (!validation$pass) {
    stop("Line contract validation failed.")
  }

  q1 <- "How has Wilmington population changed from 2013 to 2023?"
  d1 <- prep_line(df, config = list(metric_id = "pop_total", variant = "single", geo_ids = "48900"))
  p1 <- render_line(d1, config = list(title = "Line Test 1: Single Series", subtitle = q1, y_label = "Population"))

  q2 <- "How does Wilmington compare with selected peers over time?"
  d2 <- prep_line(df, config = list(metric_id = "pop_total", variant = "multi", geo_ids = c("48900", "16740", "39580")))
  p2 <- render_line(d2, config = list(title = "Line Test 2: Multi Series", subtitle = q2, y_label = "Population"))

  q3 <- "Are incomes rising faster than population-adjusted income peers over time (index base year 2013)?"
  d3 <- prep_line(df, config = list(metric_id = "calc_income_pc", variant = "indexed", geo_ids = c("48900", "16740", "39580"), base_period = 2013))
  p3 <- render_line(d3, config = list(title = "Line Test 3: Indexed Comparison", subtitle = q3, y_label = "Index (2013 = 100)"))

  out1 <- file.path(output_dir, "line_test_single.png")
  out2 <- file.path(output_dir, "line_test_multi.png")
  out3 <- file.path(output_dir, "line_test_indexed.png")

  ggplot2::ggsave(out1, plot = p1, width = 10, height = 6, dpi = 300, bg = "white")
  ggplot2::ggsave(out2, plot = p2, width = 10, height = 6, dpi = 300, bg = "white")
  ggplot2::ggsave(out3, plot = p3, width = 10, height = 6, dpi = 300, bg = "white")

  c(out1, out2, out3)
}

outputs <- run_line_tests()
print(outputs)
