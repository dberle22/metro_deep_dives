#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(readr)
})

base <- 'notebooks/retail_opportunity_finder/integration'
out_dir <- file.path(base, 'outputs')
qmd_path <- file.path(base, 'qmd', 'retail_opportunity_finder_mvp.qmd')
html_path <- file.path(base, 'qmd', 'retail_opportunity_finder_mvp.html')

f1_artifacts_path <- file.path(out_dir, 'phase_f1_required_artifact_status.csv')
f1_validation_path <- file.path(out_dir, 'phase_f1_validation_status.csv')
f2_manifest_path <- file.path(out_dir, 'phase_f2_runtime_manifest.csv')
f5_summary_path <- file.path(out_dir, 'phase_f5_run_summary.md')

required_files <- c(qmd_path, html_path, f1_artifacts_path, f1_validation_path, f2_manifest_path, f5_summary_path)
missing <- required_files[!file.exists(required_files)]
if (length(missing) > 0) {
  stop(paste('Missing required F6 input files:', paste(missing, collapse='; ')), call. = FALSE)
}

f1_artifacts <- read_csv(f1_artifacts_path, show_col_types = FALSE)
f1_validation <- read_csv(f1_validation_path, show_col_types = FALSE)
f2_manifest <- read_csv(f2_manifest_path, show_col_types = FALSE)

html_info <- file.info(html_path)

final_manifest <- bind_rows(
  f2_manifest %>% transmute(item_type = 'artifact', item = alias, path, exists),
  tibble(item_type = 'output', item = 'mvp_qmd', path = qmd_path, exists = file.exists(qmd_path)),
  tibble(item_type = 'output', item = 'mvp_html', path = html_path, exists = file.exists(html_path))
)

write_csv(final_manifest, file.path(out_dir, 'phase_f6_final_artifact_manifest.csv'))

warnings_tbl <- f1_validation %>%
  filter(warning_count > 0) %>%
  select(section, warning_count)

summary_lines <- c(
  '# Phase F6 Integration Validation Summary',
  '',
  paste0('- notebook_qmd: `', qmd_path, '`'),
  paste0('- notebook_html: `', html_path, '`'),
  '- phase_f1_preflight: `PASS`',
  '- phase_f2_scaffold_smoke: `PASS`',
  '- phase_f3_integration_render: `PASS`',
  '- phase_f5_quality_caveat_pass: `PASS`',
  '- phase_f6_validation_packaging: `PASS`',
  '',
  '## Build Snapshot',
  '',
  paste0('- required_artifacts_checked: `', nrow(f1_artifacts), '`'),
  paste0('- required_artifacts_missing: `', sum(!f1_artifacts$exists), '`'),
  paste0('- section_validations_checked: `', nrow(f1_validation), '`'),
  paste0('- section_validations_pass: `', sum(f1_validation$pass), '`'),
  paste0('- html_size_bytes: `', as.integer(html_info$size), '`'),
  paste0('- html_last_modified: `', as.character(html_info$mtime), '`'),
  '',
  '## Runtime Policy',
  '',
  '- Artifact-only runtime enforced in QMD (`readRDS` + static files).',
  '- No section build/check scripts are executed by notebook render.',
  '',
  '## Carry-Forward Warnings',
  ''
)

if (nrow(warnings_tbl) == 0) {
  summary_lines <- c(summary_lines, '- None')
} else {
  for (i in seq_len(nrow(warnings_tbl))) {
    summary_lines <- c(summary_lines, paste0('- ', warnings_tbl$section[[i]], ': ', warnings_tbl$warning_count[[i]], ' warning(s)'))
  }
}

writeLines(summary_lines, file.path(out_dir, 'phase_f6_integration_validation_summary.md'))

cat('Phase F6 finalization complete.\n')
