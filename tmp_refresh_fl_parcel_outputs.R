suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(stringr)
})

root <- "notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization/outputs/fl_all_v2"
county_root <- file.path(root, "county_outputs")

county_dirs <- list.dirs(county_root, recursive = FALSE, full.names = TRUE)
county_dirs <- county_dirs[basename(county_dirs) != "co_01"]

find_source_shp <- function(county_name) {
  slug <- county_name %>%
    str_replace_all(" County$", "") %>%
    str_to_lower() %>%
    str_replace_all("[^a-z0-9]+", "")

  candidates <- list.files(
    "../data/property_taxes/fl/data",
    pattern = paste0(slug, ".*\\.shp$"),
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(candidates) == 0) {
    return(NA_character_)
  }

  basename(candidates[[1]])
}

summary_rows <- lapply(county_dirs, function(dir) {
  county_tag <- basename(dir)
  qa_path <- file.path(dir, "parcel_geometry_join_qa.rds")
  analysis_path <- file.path(dir, "parcel_geometries_analysis.rds")
  raw_path <- file.path(dir, "parcel_geometries_raw.rds")

  if (!file.exists(qa_path) || !file.exists(analysis_path)) {
    return(NULL)
  }

  qa_obj <- readRDS(qa_path)

  if (!is.null(qa_obj[["join_qa"]])) {
    jq <- qa_obj[["join_qa"]]
    county_name <- as.character(jq$county_name[[1]])

    tibble(
      source_shp = find_source_shp(county_name),
      county_tag = county_tag,
      output_dir = dir,
      raw_path = if (file.exists(raw_path)) raw_path else NA_character_,
      analysis_path = analysis_path,
      qa_path = qa_path,
      total_rows_raw = NA_integer_,
      unmatched_rows_raw = NA_integer_,
      unmatched_rate_raw = NA_real_,
      total_rows_analysis = as.integer(jq$total_joined_rows[[1]]),
      unmatched_rows_analysis = as.integer(jq$unmatched_rows[[1]]),
      unmatched_rate_analysis = as.numeric(jq$unmatched_rate[[1]]),
      pass = as.logical(jq$unmatched_rate[[1]] <= 0.01)
    )
  } else {
    tibble(
      source_shp = as.character(qa_obj[["source_shp"]]),
      county_tag = as.character(qa_obj[["county_tag"]]),
      output_dir = dir,
      raw_path = if (file.exists(raw_path)) raw_path else NA_character_,
      analysis_path = analysis_path,
      qa_path = qa_path,
      total_rows_raw = as.integer(qa_obj[["total_rows_raw"]]),
      unmatched_rows_raw = as.integer(qa_obj[["unmatched_rows_raw"]]),
      unmatched_rate_raw = as.numeric(qa_obj[["unmatched_rate_raw"]]),
      total_rows_analysis = as.integer(qa_obj[["total_rows_analysis"]]),
      unmatched_rows_analysis = as.integer(qa_obj[["unmatched_rows_analysis"]]),
      unmatched_rate_analysis = as.numeric(qa_obj[["unmatched_rate_analysis"]]),
      pass = as.logical(qa_obj[["pass"]])
    )
  }
})

summary_tbl <- bind_rows(summary_rows) %>%
  arrange(county_tag)

saveRDS(summary_tbl, file.path(root, "parcel_geometry_join_qa_county_summary.rds"))

manifest_tbl <- summary_tbl %>%
  transmute(
    state = "FL",
    county_tag = county_tag,
    source_shp = source_shp,
    analysis_path = analysis_path,
    qa_path = qa_path,
    raw_path = raw_path,
    pass = pass
  )

saveRDS(manifest_tbl, file.path(root, "parcel_ingest_manifest.rds"))
write_csv(manifest_tbl, file.path(root, "parcel_ingest_manifest.csv"), na = "")

cat("summary_rows", nrow(summary_tbl), "\n")
print(as.data.frame(summary_tbl))
cat("\nmanifest_rows", nrow(manifest_tbl), "\n")
print(as.data.frame(manifest_tbl))
