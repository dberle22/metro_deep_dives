#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(yaml)
})

source("scripts/data_dictionary/_acs_dictionary_helpers.R")

args <- commandArgs(trailingOnly = TRUE)
selected_themes <- if (length(args) > 0) strsplit(args[1], ",", fixed = TRUE)[[1]] else character(0)
selected_themes <- trimws(selected_themes)

kpi_files <- Sys.glob("schemas/data_dictionary/layers/silver/silver__*_kpi.yml")
kpi_files <- kpi_files[!grepl("bea_|bls_|hud_|tx_tea|acs_tx_school", basename(kpi_files))]
if (length(kpi_files) == 0) stop("No ACS Silver *_kpi dictionary files found.")

all_audit <- list()
updated_files <- 0L
updated_defs <- 0L

for (yml_path in sort(kpi_files)) {
  theme <- sub("^silver__", "", basename(yml_path))
  theme <- sub("_kpi\\.yml$", "", theme)

  if (length(selected_themes) > 0 && !theme %in% selected_themes) next

  obj <- read_yaml(yml_path)

  # Base semantic map from corresponding *_base definitions
  base_yml <- file.path("schemas", "data_dictionary", "layers", "silver", paste0("silver__", theme, "_base.yml"))
  base_semantic <- list()
  if (file.exists(base_yml)) {
    b <- read_yaml(base_yml)
    for (bc in b$columns) {
      nm <- bc$name
      if (nm %in% std_key_cols) next
      def <- ifelse(is.null(bc$definition), "", as.character(bc$definition))
      key <- normalize_metric_key(nm)
      # Convert ACS exact wording to business wording when possible
      m <- regexec("^ACS\\s+\\d{4}\\s+[^[]+\\[[^]]+\\]:\\s*(.+?)\\s*\\(estimate\\)\\.?$", def)
      mm <- regmatches(def, m)[[1]]
      if (length(mm) >= 2) {
        label <- pretty_acs_label(mm[2])
        base_semantic[[key]] <- paste0(label, ".")
      } else {
        base_semantic[[key]] <- def
      }
    }
  }

  stem <- script_stem_for_theme(theme)
  silver_script <- file.path("scripts", "etl", "silver", paste0("acs_", stem, "_silver.R"))
  formula_df <- extract_assignments_from_silver_script(silver_script)

  changed <- FALSE
  for (i in seq_along(obj$columns)) {
    col <- obj$columns[[i]]
    nm <- col$name
    if (nm %in% std_key_cols) next

    old_def <- ifelse(is.null(col$definition), "", as.character(col$definition))
    old_cls <- classify_definition_strength(old_def, col$needs_confirmation)

    # Try mapping from direct base semantic by name
    semantic <- NULL
    key <- normalize_metric_key(nm)
    if (!is.null(base_semantic[[key]]) && nzchar(base_semantic[[key]])) {
      semantic <- list(definition = base_semantic[[key]], confidence = "high", formula_class = "direct_name")
    }

    # Formula-driven override if available
    form_row <- formula_df[formula_df$lhs == nm, , drop = FALSE]
    if (nrow(form_row) > 0) {
      rhs <- form_row$rhs[[1]]
      semantic <- semantic_from_formula(nm, rhs, base_semantic)
    }

    # Naming fallback
    if (is.null(semantic)) {
      if (startsWith(nm, "pct_")) {
        semantic <- list(definition = sprintf("Share of %s (0 to 1).", metric_phrase_from_name(nm)), confidence = "medium", formula_class = "name_pct")
      } else if (startsWith(nm, "rate_") || grepl("_rate$", nm)) {
        semantic <- list(definition = sprintf("Rate for %s.", metric_phrase_from_name(nm)), confidence = "medium", formula_class = "name_rate")
      } else {
        semantic <- list(definition = sprintf("Business metric for %s.", metric_phrase_from_name(nm)), confidence = "low", formula_class = "name_fallback")
      }
    }

    new_def <- semantic$definition
    new_needs <- semantic$confidence == "low"
    action <- "no_change"

    if (old_cls %in% c("weak", "undefined") && !identical(old_def, new_def)) {
      obj$columns[[i]]$definition <- new_def
      obj$columns[[i]]$needs_confirmation <- new_needs
      changed <- TRUE
      updated_defs <- updated_defs + 1L
      action <- "updated_weak_or_undefined"
    }

    all_audit[[length(all_audit) + 1L]] <- data.frame(
      table = paste0(obj$schema, ".", obj$table_name),
      column = nm,
      old_class = old_cls,
      action = action,
      confidence = semantic$confidence,
      formula_class = semantic$formula_class,
      old_definition = old_def,
      new_definition = ifelse(is.null(obj$columns[[i]]$definition), "", as.character(obj$columns[[i]]$definition)),
      stringsAsFactors = FALSE
    )
  }

  # Sync optional kpi_definitions section
  if (!is.null(obj$kpi_definitions) && length(obj$kpi_definitions) > 0) {
    for (j in seq_along(obj$kpi_definitions)) {
      kname <- obj$kpi_definitions[[j]]$kpi_name
      if (is.null(kname)) kname <- obj$kpi_definitions[[j]]$metric_name
      if (is.null(kname)) next
      match_col <- which(vapply(obj$columns, function(x) identical(x$name, kname), logical(1)))
      if (length(match_col) == 1) {
        bd <- obj$columns[[match_col]]$definition
        if (!is.null(bd) && nzchar(bd)) {
          obj$kpi_definitions[[j]]$business_definition <- bd
          if (!is.null(obj$kpi_definitions[[j]]$needs_confirmation)) {
            obj$kpi_definitions[[j]]$needs_confirmation <- isTRUE(obj$columns[[match_col]]$needs_confirmation)
          }
          changed <- TRUE
        }
      }
    }
  }

  if (changed) {
    write_yaml(obj, yml_path, indent.mapping.sequence = TRUE, line.sep = "\n")
    sync_md_columns_from_yaml(yml_path)
    updated_files <- updated_files + 1L
  }
}

audit_df <- if (length(all_audit) > 0) do.call(rbind, all_audit) else data.frame()
out_csv <- "schemas/data_dictionary/artifacts/audits/acs_kpi_semantic_fill_audit.csv"
write.csv(audit_df, out_csv, row.names = FALSE)

cat(sprintf("UPDATED_FILES=%d\n", updated_files))
cat(sprintf("UPDATED_DEFINITIONS=%d\n", updated_defs))
cat(sprintf("AUDIT_CSV=%s\n", out_csv))
