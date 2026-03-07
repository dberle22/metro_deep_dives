# Line chart smoke tests for three business questions.

source("R/visual/standards.R")
source("documents/visual_library/charts/line/prep_line.R")
source("documents/visual_library/charts/line/render_line.R")

build_sample_line_df <- function() {
  years <- 2013:2023
  geos <- data.frame(
    geo_id = c("48900", "16740", "39580"),
    geo_name = c("Wilmington, NC", "Charlotte, NC", "Raleigh, NC"),
    group = c("South Atlantic", "South Atlantic", "South Atlantic"),
    stringsAsFactors = FALSE
  )

  out <- do.call(rbind, lapply(seq_len(nrow(geos)), function(i) {
    g <- geos[i, ]

    pop <- 100000 + (years - 2013) * (2500 + i * 350) + sin(years) * 250
    inc <- 42000 + (years - 2013) * (900 + i * 120)

    rbind(
      data.frame(
        geo_level = "cbsa",
        geo_id = g$geo_id,
        geo_name = g$geo_name,
        period = years,
        time_window = "level",
        metric_id = "population",
        metric_label = "Population",
        metric_value = pop,
        source = "synthetic_line_test",
        vintage = "2026-03-02",
        group = g$group,
        highlight_flag = g$geo_id == "48900",
        benchmark_value = NA_real_,
        index_base_period = NA_integer_,
        note = NA_character_,
        stringsAsFactors = FALSE
      ),
      data.frame(
        geo_level = "cbsa",
        geo_id = g$geo_id,
        geo_name = g$geo_name,
        period = years,
        time_window = "level",
        metric_id = "inc_pc",
        metric_label = "Income Per Capita",
        metric_value = inc,
        source = "synthetic_line_test",
        vintage = "2026-03-02",
        group = g$group,
        highlight_flag = g$geo_id == "48900",
        benchmark_value = NA_real_,
        index_base_period = NA_integer_,
        note = NA_character_,
        stringsAsFactors = FALSE
      )
    )
  }))

  out
}

run_line_tests <- function() {
  df <- build_sample_line_df()

  # Q1 Single-series
  q1 <- "How has Wilmington population changed from 2013 to 2023?"
  d1 <- prep_line(df, metric_id = "population", variant = "single", geo_ids = "48900")
  p1 <- render_line(d1, title = "Line Test 1: Single Series", subtitle = q1, y_label = "Population")
  ggplot2::ggsave(
    filename = "documents/visual_library/charts/line/sample_output/line_test_single.png",
    plot = p1,
    width = 10,
    height = 6,
    dpi = 300,
    bg = "white"
  )

  # Q2 Multi-series
  q2 <- "How does Wilmington compare with selected peers over time?"
  d2 <- prep_line(df, metric_id = "population", variant = "multi", geo_ids = c("48900", "16740", "39580"))
  p2 <- render_line(d2, title = "Line Test 2: Multi Series", subtitle = q2, y_label = "Population")
  ggplot2::ggsave(
    filename = "documents/visual_library/charts/line/sample_output/line_test_multi.png",
    plot = p2,
    width = 10,
    height = 6,
    dpi = 300,
    bg = "white"
  )

  # Q3 Indexed comparison
  q3 <- "Are incomes rising faster over time across selected metros (index base year 2013)?"
  d3 <- prep_line(df, metric_id = "inc_pc", variant = "indexed", geo_ids = c("48900", "16740", "39580"), base_period = 2013)
  p3 <- render_line(d3, title = "Line Test 3: Indexed Comparison", subtitle = q3, y_label = "Index (2013 = 100)")
  ggplot2::ggsave(
    filename = "documents/visual_library/charts/line/sample_output/line_test_indexed.png",
    plot = p3,
    width = 10,
    height = 6,
    dpi = 300,
    bg = "white"
  )

  c(
    "documents/visual_library/charts/line/sample_output/line_test_single.png",
    "documents/visual_library/charts/line/sample_output/line_test_multi.png",
    "documents/visual_library/charts/line/sample_output/line_test_indexed.png"
  )
}

outputs <- run_line_tests()
print(outputs)
