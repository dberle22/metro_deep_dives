#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(jsonlite)
})

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

parse_args <- function(args) {
  parsed <- list(
    markets = c("jacksonville_fl"),
    through_section = 3L
  )

  for (arg in args) {
    if (startsWith(arg, "--markets=")) {
      parsed$markets <- strsplit(sub("^--markets=", "", arg), ",", fixed = TRUE)[[1]]
      parsed$markets <- trimws(parsed$markets)
      parsed$markets <- parsed$markets[nzchar(parsed$markets)]
    } else if (startsWith(arg, "--through_section=")) {
      parsed$through_section <- as.integer(sub("^--through_section=", "", arg))
    } else {
      stop(paste0("Unknown argument: ", arg), call. = FALSE)
    }
  }

  if (length(parsed$markets) == 0) {
    stop("At least one market key is required via --markets.", call. = FALSE)
  }

  if (is.na(parsed$through_section) || parsed$through_section < 1L || parsed$through_section > 3L) {
    stop("--through_section must be an integer from 1 to 3 for Sprint 3 Workstream B.", call. = FALSE)
  }

  invalid_markets <- setdiff(parsed$markets, names(MARKET_PROFILES))
  if (length(invalid_markets) > 0) {
    stop(
      paste0(
        "Unknown market key(s): ",
        paste(invalid_markets, collapse = ", "),
        ". Valid options: ",
        paste(names(MARKET_PROFILES), collapse = ", ")
      ),
      call. = FALSE
    )
  }

  parsed
}

section_registry <- function() {
  data.frame(
    section_num = c(1L, 1L, 2L, 2L, 2L, 3L, 3L, 3L),
    section_id = c(
      "01_setup", "01_setup",
      "02_market_overview", "02_market_overview", "02_market_overview",
      "03_eligibility_scoring", "03_eligibility_scoring", "03_eligibility_scoring"
    ),
    step_type = c("build", "checks", "build", "checks", "visuals", "build", "checks", "visuals"),
    script_path = c(
      "notebooks/retail_opportunity_finder/sections/01_setup/section_01_build.R",
      "notebooks/retail_opportunity_finder/sections/01_setup/section_01_checks.R",
      "notebooks/retail_opportunity_finder/sections/02_market_overview/section_02_build.R",
      "notebooks/retail_opportunity_finder/sections/02_market_overview/section_02_checks.R",
      "notebooks/retail_opportunity_finder/sections/02_market_overview/section_02_visuals.R",
      "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/section_03_build.R",
      "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/section_03_checks.R",
      "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/section_03_visuals.R"
    ),
    stringsAsFactors = FALSE
  )
}

section_output_dirs <- function(market_key, through_section = 3L) {
  registry <- section_registry() %>%
    filter(section_num <= through_section) %>%
    distinct(section_id, section_num)

  dirs <- lapply(registry$section_id, function(section_id) {
    resolve_market_output_dir(section_id, key = market_key)
  })
  names(dirs) <- registry$section_id
  dirs
}

evaluate_validation_report <- function(section_id, market_key) {
  artifact_name <- dplyr::case_when(
    section_id == "01_setup" ~ "section_01_validation_report",
    section_id == "02_market_overview" ~ "section_02_validation_report",
    section_id == "03_eligibility_scoring" ~ "section_03_validation_report",
    TRUE ~ NA_character_
  )

  if (is.na(artifact_name)) {
    return(list(report_path = NA_character_, validation_pass = NA, qa_summary = NA_character_))
  }

  report_path <- tryCatch(
    read_artifact_path(section_id, artifact_name, key = market_key),
    error = function(e) NA_character_
  )

  if (is.na(report_path) || !file.exists(report_path)) {
    return(list(report_path = report_path, validation_pass = FALSE, qa_summary = "missing validation report"))
  }

  report <- readRDS(report_path)

  validation_pass <- switch(
    section_id,
    "01_setup" = all(vapply(report$column_checks, `[[`, logical(1), "pass")) &&
      isTRUE(report$market_profile_check$pass) &&
      all(vapply(report$key_checks, `[[`, logical(1), "pass")) &&
      all(vapply(report$geometry_checks, `[[`, logical(1), "pass")),
    "02_market_overview" = all(vapply(report$checks, `[[`, logical(1), "pass")) &&
      all(unlist(report$logic_checks)),
    "03_eligibility_scoring" = all(vapply(report$checks[1:6], `[[`, logical(1), "pass")) &&
      isTRUE(report$checks$geometry_check$pass) &&
      all(unlist(report$logic_checks)),
    FALSE
  )

  qa_summary <- switch(
    section_id,
    "01_setup" = paste0(
      "columns=", all(vapply(report$column_checks, `[[`, logical(1), "pass")),
      "; keys=", all(vapply(report$key_checks, `[[`, logical(1), "pass")),
      "; geometry=", all(vapply(report$geometry_checks, `[[`, logical(1), "pass"))
    ),
    "02_market_overview" = paste0(
      "schema=", all(vapply(report$checks, `[[`, logical(1), "pass")),
      "; logic=", all(unlist(report$logic_checks))
    ),
    "03_eligibility_scoring" = paste0(
      "schema=", all(vapply(report$checks[1:6], `[[`, logical(1), "pass")),
      "; geometry=", isTRUE(report$checks$geometry_check$pass),
      "; logic=", all(unlist(report$logic_checks))
    ),
    NA_character_
  )

  list(
    report_path = report_path,
    validation_pass = validation_pass,
    qa_summary = qa_summary
  )
}

evaluate_visual_outputs <- function(section_id, market_key) {
  expected_artifacts <- switch(
    section_id,
    "02_market_overview" = c(
      resolve_output_path(section_id, "section_02_visual_objects", key = market_key),
      resolve_output_path(section_id, "section_02_pop_trend_plot", ext = "png", key = market_key),
      resolve_output_path(section_id, "section_02_market_context_map", ext = "png", key = market_key),
      resolve_output_path(section_id, "section_02_market_context_map_style_a", ext = "png", key = market_key),
      resolve_output_path(section_id, "section_02_market_context_map_style_b", ext = "png", key = market_key),
      resolve_output_path(section_id, "section_02_distribution_plot", ext = "png", key = market_key)
    ),
    "03_eligibility_scoring" = c(
      resolve_output_path(section_id, "section_03_visual_objects", key = market_key),
      resolve_output_path(section_id, "section_03_price_hist", ext = "png", key = market_key),
      resolve_output_path(section_id, "section_03_growth_hist", ext = "png", key = market_key),
      resolve_output_path(section_id, "section_03_eligible_map", ext = "png", key = market_key),
      resolve_output_path(section_id, "section_03_score_hist", ext = "png", key = market_key),
      resolve_output_path(section_id, "section_03_growth_density_scatter", ext = "png", key = market_key)
    ),
    character()
  )

  existing <- file.exists(expected_artifacts)
  missing_paths <- expected_artifacts[!existing]

  list(
    artifact_path = if (length(expected_artifacts) > 0) expected_artifacts[[1]] else NA_character_,
    quality_pass = length(expected_artifacts) > 0 && all(existing),
    quality_summary = if (length(missing_paths) == 0) {
      paste0("rendered=", length(expected_artifacts))
    } else {
      paste0("missing=", paste(missing_paths, collapse = " | "))
    }
  )
}

run_step <- function(batch_id, market_key, step_row, logs_root_dir) {
  market_log_dir <- file.path(logs_root_dir, batch_id, market_key)
  dir.create(market_log_dir, recursive = TRUE, showWarnings = FALSE)

  log_stub <- paste0(sprintf("%02d", step_row$section_num), "_", step_row$step_type, "_", step_row$section_id)
  stdout_file <- file.path(market_log_dir, paste0(log_stub, ".stdout.log"))
  stderr_file <- file.path(market_log_dir, paste0(log_stub, ".stderr.log"))
  started_at <- Sys.time()

  exit_code <- system2(
    command = "Rscript",
    args = c(step_row$script_path),
    stdout = stdout_file,
    stderr = stderr_file,
    env = c(paste0("ROF_MARKET_KEY=", market_key))
  )

  finished_at <- Sys.time()
  duration <- as.numeric(difftime(finished_at, started_at, units = "secs"))
  status <- if (identical(exit_code, 0L)) "passed" else "failed"
  quality <- if (step_row$step_type == "checks") {
    evaluate_validation_report(step_row$section_id, market_key)
  } else if (step_row$step_type == "visuals") {
    evaluate_visual_outputs(step_row$section_id, market_key)
  } else {
    list(artifact_path = NA_character_, quality_pass = NA, quality_summary = NA_character_)
  }

  data.frame(
    batch_id = batch_id,
    market_key = market_key,
    cbsa_code = MARKET_PROFILES[[market_key]]$cbsa_code,
    section_num = step_row$section_num,
    section_id = step_row$section_id,
    step_type = step_row$step_type,
    step_id = paste0(sprintf("%02d", step_row$section_num), "_", step_row$step_type),
    script_path = step_row$script_path,
    status = status,
    exit_code = as.integer(exit_code),
    started_at = format(started_at, tz = "UTC", usetz = TRUE),
    finished_at = format(finished_at, tz = "UTC", usetz = TRUE),
    runtime_seconds = round(duration, 3),
    output_dir = resolve_market_output_dir(step_row$section_id, key = market_key),
    primary_artifact_path = quality$artifact_path %||% quality$report_path,
    quality_pass = quality$quality_pass %||% quality$validation_pass,
    quality_summary = quality$quality_summary %||% quality$qa_summary,
    stdout_log = stdout_file,
    stderr_log = stderr_file,
    stringsAsFactors = FALSE
  )
}

run_market <- function(batch_id, market_key, registry, logs_root_dir) {
  rows <- vector("list", nrow(registry))

  for (i in seq_len(nrow(registry))) {
    step_row <- registry[i, , drop = FALSE]
    result <- run_step(batch_id, market_key, step_row, logs_root_dir = logs_root_dir)
    rows[[i]] <- result

    if (!identical(result$exit_code[[1]], 0L)) {
      break
    }
  }

  bind_rows(rows)
}

build_market_summary <- function(batch_id, args, manifests) {
  markets <- unique(manifests$market_key)

  bind_rows(lapply(markets, function(market_key) {
    market_rows <- manifests %>% filter(.data$market_key == .env$market_key)
    failed_row <- market_rows %>% filter(status != "passed") %>% slice(1)
    output_dirs <- section_output_dirs(market_key, through_section = args$through_section)

    data.frame(
      batch_id = batch_id,
      market_key = market_key,
      cbsa_code = MARKET_PROFILES[[market_key]]$cbsa_code,
      through_section = args$through_section,
      market_status = if (nrow(failed_row) == 0) "passed" else "failed",
      failed_step_id = if (nrow(failed_row) == 0) NA_character_ else failed_row$step_id[[1]],
      failed_script_path = if (nrow(failed_row) == 0) NA_character_ else failed_row$script_path[[1]],
      total_steps = nrow(market_rows),
      passed_steps = sum(market_rows$status == "passed"),
      runtime_seconds = round(sum(market_rows$runtime_seconds, na.rm = TRUE), 3),
      section_01_output_dir = if ("01_setup" %in% names(output_dirs)) output_dirs[["01_setup"]] else NA_character_,
      section_02_output_dir = if ("02_market_overview" %in% names(output_dirs)) output_dirs[["02_market_overview"]] else NA_character_,
      section_03_output_dir = if ("03_eligibility_scoring" %in% names(output_dirs)) output_dirs[["03_eligibility_scoring"]] else NA_character_,
      stringsAsFactors = FALSE
    )
  }))
}

args <- parse_args(commandArgs(trailingOnly = TRUE))
registry <- section_registry() %>% filter(section_num <= args$through_section)
batch_id <- format(Sys.time(), "%Y%m%dT%H%M%S")

message(
  paste0(
    "Running ROF market batch: markets=",
    paste(args$markets, collapse = ","),
    "; through_section=",
    args$through_section
  )
)

integration_output_dir <- "notebooks/retail_opportunity_finder/integration/outputs"
dir.create(integration_output_dir, recursive = TRUE, showWarnings = FALSE)
logs_root_dir <- file.path(integration_output_dir, "market_batch_logs")
dir.create(logs_root_dir, recursive = TRUE, showWarnings = FALSE)

step_manifest <- bind_rows(lapply(args$markets, function(market_key) {
  run_market(batch_id, market_key, registry, logs_root_dir = logs_root_dir)
}))

market_summary <- build_market_summary(batch_id, args, step_manifest)

csv_path <- file.path(integration_output_dir, "market_batch_manifest.csv")
json_path <- file.path(integration_output_dir, "market_batch_manifest.json")

write_csv(step_manifest, csv_path)
write_json(
  list(
    batch_id = batch_id,
    run_timestamp = format(Sys.time(), tz = "UTC", usetz = TRUE),
    markets = args$markets,
    through_section = args$through_section,
    known_limitations = c(
      "Sprint 3 Workstream B runs Sections 01-03 only, including Section 02-03 visuals.",
      "Full end-to-end parcel validation is deferred until geometry adapter and parcel ETL work are in place."
    ),
    market_summary = market_summary,
    step_manifest = step_manifest
  ),
  path = json_path,
  auto_unbox = TRUE,
  pretty = TRUE
)

print(market_summary)
message(paste0("Wrote batch manifest: ", csv_path))
message(paste0("Wrote batch manifest: ", json_path))

if (any(step_manifest$status != "passed")) {
  stop("One or more market batch steps failed. See market batch manifest for details.", call. = FALSE)
}

message("Market batch run complete.")
