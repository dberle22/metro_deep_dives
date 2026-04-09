#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
})

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

parse_args <- function(args) {
  parsed <- list(
    through_section = 6L
  )

  for (arg in args) {
    if (startsWith(arg, "--through_section=")) {
      parsed$through_section <- as.integer(sub("^--through_section=", "", arg))
    } else {
      stop(paste0("Unknown argument: ", arg), call. = FALSE)
    }
  }

  if (is.na(parsed$through_section) || parsed$through_section < 1L || parsed$through_section > 6L) {
    stop("--through_section must be an integer from 1 to 6.", call. = FALSE)
  }

  parsed
}

step_registry <- function() {
  data.frame(
    section_num = c(
      1L, 1L, 1L,
      2L, 2L, 2L,
      3L, 3L, 3L,
      4L, 4L, 4L, 4L, 4L, 4L,
      5L, 5L, 5L,
      6L, 6L, 6L
    ),
    step_id = c(
      "01_build", "01_checks", "01_visuals",
      "02_build", "02_checks", "02_visuals",
      "03_build", "03_checks", "03_visuals",
      "04_build", "04_checks", "04_visuals", "04_cluster_build", "04_cluster_checks", "04_cluster_visuals",
      "05_build", "05_checks", "05_visuals",
      "06_build", "06_visuals", "06_checks"
    ),
    script_path = c(
      "notebooks/retail_opportunity_finder/notebook_build/sections/01_setup/section_01_build.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/01_setup/section_01_checks.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/01_setup/section_01_visuals.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/02_market_overview/section_02_build.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/02_market_overview/section_02_checks.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/02_market_overview/section_02_visuals.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/03_eligibility_scoring/section_03_build.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/03_eligibility_scoring/section_03_checks.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/03_eligibility_scoring/section_03_visuals.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/04_zones/section_04_build.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/04_zones/section_04_checks.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/04_zones/section_04_visuals.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/04_zones/cluster_build/section_04_cluster_build.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/04_zones/cluster_build/section_04_cluster_checks.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/04_zones/cluster_build/section_04_cluster_visuals.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/05_parcels/section_05_build.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/05_parcels/section_05_checks.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/05_parcels/section_05_visuals.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/06_conclusion_appendix/section_06_build.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/06_conclusion_appendix/section_06_visuals.R",
      "notebooks/retail_opportunity_finder/notebook_build/sections/06_conclusion_appendix/section_06_checks.R"
    ),
    stringsAsFactors = FALSE
  )
}

run_step <- function(step_row) {
  started_at <- Sys.time()
  exit_code <- system2("Rscript", args = step_row$script_path)
  finished_at <- Sys.time()

  data.frame(
    step_id = step_row$step_id,
    script_path = step_row$script_path,
    status = if (identical(exit_code, 0L)) "passed" else "failed",
    exit_code = as.integer(exit_code),
    started_at = format(started_at, tz = "UTC", usetz = TRUE),
    finished_at = format(finished_at, tz = "UTC", usetz = TRUE),
    runtime_seconds = round(as.numeric(difftime(finished_at, started_at, units = "secs")), 3),
    stringsAsFactors = FALSE
  )
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
registry <- step_registry() %>% filter(section_num <= args$through_section)

message(
  paste0(
    "Running notebook_build consumer flow for market=",
    get_market_profile()$market_key,
    "; through_section=",
    args$through_section
  )
)

results <- bind_rows(lapply(seq_len(nrow(registry)), function(i) {
  step_row <- registry[i, , drop = FALSE]
  run_step(step_row)
}))

print(results)

if (any(results$status != "passed")) {
  stop("Notebook-build consumer flow failed.", call. = FALSE)
}

message("Notebook-build consumer flow complete.")
