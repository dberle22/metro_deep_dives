# Notebook-build Section 04 cluster script
# Purpose: Read published cluster-zone tables and emit Section 04 cluster compatibility artifacts.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()
source("notebooks/retail_opportunity_finder/notebook_build/_shared/read_only_build_helpers.R")

message("Running notebook_build section 04 cluster build")

profile <- get_market_profile()
con <- connect_project_duckdb(read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

assert_duckdb_tables(
  con,
  c(
    "zones.cluster_assignments",
    "zones.cluster_zone_summary",
    "zones.cluster_zone_geometries"
  )
)

cluster_assignments <- read_market_table(
  con,
  "zones.cluster_assignments",
  profile = profile,
  order_sql = "cluster_order, tract_geoid"
) %>%
  drop_platform_metadata()

cluster_zones <- read_market_sf_table(
  con,
  "zones.cluster_zone_geometries",
  profile = profile,
  order_sql = "cluster_order"
) %>%
  drop_platform_metadata() %>%
  sf::st_make_valid() %>%
  arrange(cluster_order)

cluster_zone_summary <- read_market_table(
  con,
  "zones.cluster_zone_summary",
  profile = profile,
  order_sql = "cluster_order"
) %>%
  drop_platform_metadata()

cluster_params <- build_default_cluster_params()

contiguity_summary_path <- read_artifact_path("04_zones", "section_04_zone_summary")
contiguity_summary <- readRDS(contiguity_summary_path)

cluster_vs_contiguity_comparison <- tibble::tibble(
  zone_system = c("contiguity", "cluster"),
  zone_count = c(nrow(contiguity_summary), nrow(cluster_zone_summary)),
  median_zone_area_sq_mi = c(
    median(contiguity_summary$zone_area_sq_mi, na.rm = TRUE),
    median(cluster_zone_summary$zone_area_sq_mi, na.rm = TRUE)
  ),
  mean_tract_score_mean = c(
    mean(contiguity_summary$mean_tract_score, na.rm = TRUE),
    mean(cluster_zone_summary$mean_tract_score, na.rm = TRUE)
  )
)

save_artifact(
  cluster_assignments,
  resolve_output_path("04_zones", "section_04_cluster_assignments")
)
save_artifact(
  cluster_zones,
  resolve_output_path("04_zones", "section_04_cluster_zones")
)
save_artifact(
  cluster_zone_summary,
  resolve_output_path("04_zones", "section_04_cluster_zone_summary")
)
save_artifact(
  cluster_vs_contiguity_comparison,
  resolve_output_path("04_zones", "section_04_cluster_vs_contiguity_comparison")
)
save_artifact(
  cluster_params,
  resolve_output_path("04_zones", "section_04_cluster_params")
)

message("Notebook-build Section 04 cluster compatibility artifacts complete.")
