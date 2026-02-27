source("notebooks/retail_opportunity_finder/sections/05_parcels/parcel_standardization/00_config.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(sf)
  library(glue)
})

list_parcel_shapefiles <- function(shape_root) {
  list.files(shape_root, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)
}

read_parcel_shape <- function(path, target_epsg = 4326) {
  x <- sf::st_read(path, quiet = TRUE)
  crs <- sf::st_crs(x)
  if (!is.na(crs)) {
    x <- tryCatch(
      sf::st_transform(x, target_epsg),
      error = function(e) {
        warning(glue("CRS transform failed for {path}: {e$message}"))
        x
      }
    )
  } else {
    warning(glue("Shapefile missing CRS metadata; leaving CRS as-is: {path}"))
  }
  x$source_shp <- basename(path)
  x
}

derive_shape_join_key <- function(sf_obj) {
  names_l <- tolower(names(sf_obj))

  if ("parcel_id" %in% names_l) {
    col <- names(sf_obj)[which(names_l == "parcel_id")[1]]
    return(normalize_join_key(sf_obj[[col]]))
  }
  if ("alt_key" %in% names_l) {
    col <- names(sf_obj)[which(names_l == "alt_key")[1]]
    return(normalize_join_key(sf_obj[[col]]))
  }

  stop("No parcel join key found in shapefile (expected parcel_id or alt_key).", call. = FALSE)
}

derive_county_tag <- function(shape_df, shp_path) {
  if ("CO_NO" %in% names(shape_df)) {
    co <- as.character(shape_df$CO_NO)
    co <- co[!is.na(co) & co != "0" & co != ""]
    if (length(co) > 0) {
      co_mode <- names(sort(table(co), decreasing = TRUE))[1]
      return(sprintf("co_%s", stringr::str_pad(co_mode, width = 2, side = "left", pad = "0")))
    }
  }
  tools::file_path_sans_ext(basename(shp_path))
}

trim_attributes_for_join <- function(attrs) {
  keep_cols <- c(
    "join_key", "source_file", "vintage",
    "parcel_id", "alt_key", "county", "county_name",
    "use_code", "definition", "type",
    "owner_name", "owner_addr", "phys_addr",
    "land_value", "impro_value", "total_value", "living_area_sqft",
    "sale_qual_code", "sale_price1", "sale_yr1", "sale_mo1",
    "sale_price2", "sale_yr2", "sale_mo2"
  )
  attrs %>% select(any_of(keep_cols))
}

build_analysis_geometry <- function(shapes) {
  shapes_with_key <- shapes %>% filter(!is.na(join_key) & join_key != "")
  shapes_missing_key <- shapes %>% filter(is.na(join_key) | join_key == "")

  key_counts <- shapes_with_key %>%
    sf::st_drop_geometry() %>%
    count(source_shp, CO_NO, join_key, name = "geom_piece_count")

  single_key_groups <- key_counts %>% filter(geom_piece_count == 1L)
  duplicate_key_groups <- key_counts %>% filter(geom_piece_count > 1L)

  analysis_single <- shapes_with_key %>%
    semi_join(single_key_groups, by = c("source_shp", "CO_NO", "join_key")) %>%
    mutate(geom_piece_count = 1L)

  analysis_dissolved <- shapes_with_key %>%
    semi_join(duplicate_key_groups, by = c("source_shp", "CO_NO", "join_key")) %>%
    group_by(source_shp, CO_NO, join_key) %>%
    summarise(
      geom_piece_count = n(),
      do_union = FALSE,
      .groups = "drop"
    )

  if (nrow(shapes_missing_key) > 0) {
    shapes_missing_key <- shapes_missing_key %>%
      mutate(geom_piece_count = 1L)
    bind_rows(analysis_single, analysis_dissolved, shapes_missing_key)
  } else {
    bind_rows(analysis_single, analysis_dissolved)
  }
}

write_county_outputs <- function(county_root, joined_raw, joined_analysis, qa) {
  dir.create(county_root, recursive = TRUE, showWarnings = FALSE)
  raw_path <- file.path(county_root, "parcel_geometries_raw.rds")
  analysis_path <- file.path(county_root, "parcel_geometries_analysis.rds")
  qa_path <- file.path(county_root, "parcel_geometry_join_qa.rds")

  saveRDS(joined_raw, raw_path)
  saveRDS(joined_analysis, analysis_path)
  saveRDS(qa, qa_path)

  list(raw_path = raw_path, analysis_path = analysis_path, qa_path = qa_path)
}

run_parcel_geometry_standardization <- function() {
  paths <- parcel_standardization_paths()
  assert_required_path(paths$property_shape_root, "PROPERTY_SHAPE_ROOT", expected = "directory")

  if (!file.exists(paths$standardized_attr_rds)) {
    stop(
      glue("Missing standardized parcel attributes: {paths$standardized_attr_rds}. Run 01_ingest_parcel_tabular.R first."),
      call. = FALSE
    )
  }

  attrs <- readRDS(paths$standardized_attr_rds) %>%
    mutate(
      join_key = dplyr::coalesce(parcel_id, alt_key),
      join_key = normalize_join_key(join_key)
    ) %>%
    trim_attributes_for_join()

  shp_files <- list_parcel_shapefiles(paths$property_shape_root)
  if (length(shp_files) == 0) {
    stop(glue("No shapefiles found under PROPERTY_SHAPE_ROOT: {paths$property_shape_root}"), call. = FALSE)
  }

  message(glue("Found {length(shp_files)} shapefile(s)."))
  county_root <- file.path(paths$standardized_root, "county_outputs")
  dir.create(county_root, recursive = TRUE, showWarnings = FALSE)

  qa_rows <- lapply(shp_files, function(shp_path) {
    shape <- read_parcel_shape(shp_path, target_epsg = 4326)
    shape$join_key <- derive_shape_join_key(shape)
    shape <- shape %>% mutate(join_key = normalize_join_key(join_key))

    county_tag <- derive_county_tag(shape, shp_path)
    county_dir <- file.path(county_root, county_tag)

    joined_raw <- shape %>%
      left_join(attrs, by = "join_key")

    analysis_shapes <- build_analysis_geometry(shape)
    joined_analysis <- analysis_shapes %>%
      left_join(attrs, by = "join_key") %>%
      mutate(
        qa_missing_join_key = is.na(join_key) | join_key == "",
        qa_zero_county = as.character(CO_NO) == "0"
      )

    unmatched_threshold <- 0.01
    unmatched_rows_raw <- sum(is.na(joined_raw[["source_file"]]))
    unmatched_rows_analysis <- sum(is.na(joined_analysis[["source_file"]]))
    total_rows_raw <- nrow(joined_raw)
    total_rows_analysis <- nrow(joined_analysis)
    unmatched_rate_raw <- if (total_rows_raw > 0) unmatched_rows_raw / total_rows_raw else NA_real_
    unmatched_rate_analysis <- if (total_rows_analysis > 0) unmatched_rows_analysis / total_rows_analysis else NA_real_

    qa <- list(
      generated_at = as.character(Sys.time()),
      source_shp = basename(shp_path),
      county_tag = county_tag,
      total_rows_raw = total_rows_raw,
      unmatched_rows_raw = unmatched_rows_raw,
      unmatched_rate_raw = unmatched_rate_raw,
      total_rows_analysis = total_rows_analysis,
      unmatched_rows_analysis = unmatched_rows_analysis,
      unmatched_rate_analysis = unmatched_rate_analysis,
      unmatched_threshold = unmatched_threshold,
      pass = !is.na(unmatched_rate_raw) && unmatched_rate_raw <= unmatched_threshold
    )

    out_paths <- write_county_outputs(county_dir, joined_raw, joined_analysis, qa)
    message(glue("Wrote county outputs: {county_tag} -> {county_dir}"))
    if (!qa$pass) {
      warning(glue("County {county_tag} raw unmatched rate {round(100 * unmatched_rate_raw, 3)}% exceeded 1.0%"))
    }

    data.frame(
      source_shp = basename(shp_path),
      county_tag = county_tag,
      output_dir = county_dir,
      raw_path = out_paths$raw_path,
      analysis_path = out_paths$analysis_path,
      qa_path = out_paths$qa_path,
      total_rows_raw = total_rows_raw,
      unmatched_rows_raw = unmatched_rows_raw,
      unmatched_rate_raw = unmatched_rate_raw,
      total_rows_analysis = total_rows_analysis,
      unmatched_rows_analysis = unmatched_rows_analysis,
      unmatched_rate_analysis = unmatched_rate_analysis,
      pass = qa$pass,
      stringsAsFactors = FALSE
    )
  })

  qa_summary <- bind_rows(qa_rows) %>% arrange(desc(unmatched_rate_raw))
  qa_summary_path <- file.path(paths$standardized_root, "parcel_geometry_join_qa_county_summary.rds")
  saveRDS(qa_summary, qa_summary_path)
  message(glue("Wrote county QA summary: {qa_summary_path}"))

  invisible(qa_summary)
}

if (identical(environment(), globalenv())) {
  run_parcel_geometry_standardization()
}

