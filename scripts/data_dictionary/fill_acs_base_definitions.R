#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(yaml)
})

source("scripts/data_dictionary/_acs_dictionary_helpers.R")

args <- commandArgs(trailingOnly = TRUE)
selected_themes <- if (length(args) > 0) strsplit(args[1], ",", fixed = TRUE)[[1]] else character(0)
selected_themes <- trimws(selected_themes)

base_files <- Sys.glob("schemas/data_dictionary/layers/silver/silver__*_base.yml")
base_files <- base_files[!grepl("bea_|bls_|hud_|tx_tea|acs_tx_school", basename(base_files))]

if (length(base_files) == 0) stop("No ACS Silver *_base dictionary files found.")

lookup <- load_acs_lookup_from_db()
lookup_available <- nrow(lookup) > 0

if (!lookup_available) {
  message("WARNING: silver.acs_variable_dictionary not available; base fill will rely on existing text/mappings only.")
}

all_audit <- list()
updated_files <- 0L
updated_defs <- 0L

for (yml_path in sort(base_files)) {
  theme <- sub("^silver__", "", basename(yml_path))
  theme <- sub("_base\\.yml$", "", theme)

  if (length(selected_themes) > 0 && !theme %in% selected_themes) next

  stem <- script_stem_for_theme(theme)
  staging_script <- file.path("scripts", "etl", "staging", paste0("get_acs_", stem, ".R"))
  map_df <- extract_var_map_from_staging_script(staging_script)

  obj <- read_yaml(yml_path)
  changed <- FALSE

  for (i in seq_along(obj$columns)) {
    col <- obj$columns[[i]]
    nm <- col$name

    if (nm %in% std_key_cols) {
      all_audit[[length(all_audit) + 1L]] <- data.frame(
        table = paste0(obj$schema, ".", obj$table_name),
        column = nm,
        action = "skip_standard_key",
        mapping_status = "n/a",
        old_definition = ifelse(is.null(col$definition), "", as.character(col$definition)),
        new_definition = ifelse(is.null(col$definition), "", as.character(col$definition)),
        stringsAsFactors = FALSE
      )
      next
    }

    old_def <- ifelse(is.null(col$definition), "", as.character(col$definition))
    old_cls <- classify_definition_strength(old_def, col$needs_confirmation)
    metric_key <- normalize_metric_key(nm)

    # Attempt mapping from staging vars
    match_map <- map_df[map_df$silver_estimate_column == nm | map_df$metric_key == metric_key, , drop = FALSE]
    match_map <- unique(match_map)

    new_def <- old_def
    new_needs_confirmation <- ifelse(is.null(col$needs_confirmation), TRUE, isTRUE(col$needs_confirmation))
    mapping_status <- "unmapped"
    action <- "no_change"

    if (nrow(match_map) > 0 && lookup_available) {
      merged <- merge(match_map, lookup, by = c("metric_key", "silver_estimate_column", "acs_variable"), all.x = TRUE)
      # Prefer matched label rows
      if (nrow(merged) > 0) {
        if ("label_match_status" %in% names(merged)) {
          ord <- order(merged$label_match_status != "matched")
          merged <- merged[ord, , drop = FALSE]
        }

        row <- merged[1, , drop = FALSE]
        if (!is.na(row$acs_label_clean[[1]]) && !is.na(row$acs_concept_2024[[1]])) {
          y <- if (!is.na(row$lookup_year[[1]])) row$lookup_year[[1]] else 2024L
          new_def <- build_acs_definition(row$acs_concept_2024[[1]], row$acs_variable[[1]], row$acs_label_clean[[1]], y)
          new_needs_confirmation <- FALSE
          mapping_status <- "mapped_with_acs_lookup"
        } else {
          mapping_status <- "mapped_no_acs_label"
        }
      }
    } else if (nrow(match_map) > 0) {
      mapping_status <- "mapped_script_only"
    }

    if (old_cls %in% c("weak", "undefined") && nzchar(new_def) && !identical(old_def, new_def)) {
      obj$columns[[i]]$definition <- new_def
      obj$columns[[i]]$needs_confirmation <- new_needs_confirmation
      changed <- TRUE
      updated_defs <- updated_defs + 1L
      action <- "updated_definition"
    } else if (old_cls == "strong" && mapping_status == "mapped_with_acs_lookup" && grepl("^ACS ", old_def) && !identical(old_def, new_def)) {
      # normalize existing ACS definition text to canonical format
      obj$columns[[i]]$definition <- new_def
      obj$columns[[i]]$needs_confirmation <- FALSE
      changed <- TRUE
      updated_defs <- updated_defs + 1L
      action <- "normalized_acs_definition"
    }

    all_audit[[length(all_audit) + 1L]] <- data.frame(
      table = paste0(obj$schema, ".", obj$table_name),
      column = nm,
      action = action,
      mapping_status = mapping_status,
      old_definition = old_def,
      new_definition = ifelse(is.null(obj$columns[[i]]$definition), "", as.character(obj$columns[[i]]$definition)),
      stringsAsFactors = FALSE
    )
  }

  if (changed) {
    write_yaml(obj, yml_path, indent.mapping.sequence = TRUE, line.sep = "\n")
    sync_md_columns_from_yaml(yml_path)
    updated_files <- updated_files + 1L
  }
}

audit_df <- if (length(all_audit) > 0) do.call(rbind, all_audit) else data.frame()
out_csv <- "schemas/data_dictionary/artifacts/audits/acs_base_definition_fill_audit.csv"
write.csv(audit_df, out_csv, row.names = FALSE)

cat(sprintf("UPDATED_FILES=%d\n", updated_files))
cat(sprintf("UPDATED_DEFINITIONS=%d\n", updated_defs))
cat(sprintf("LOOKUP_AVAILABLE=%s\n", ifelse(lookup_available, "yes", "no")))
cat(sprintf("AUDIT_CSV=%s\n", out_csv))
