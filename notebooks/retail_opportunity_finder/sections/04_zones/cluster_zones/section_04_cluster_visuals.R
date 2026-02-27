# Section 04 cluster visuals script
# Purpose: create cluster-zone map and summary visual outputs.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 04 cluster visuals")

cluster_zones <- readRDS("notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_zones.rds")
cluster_zone_summary <- readRDS("notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_zone_summary.rds")
zone_inputs <- readRDS("notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_zone_input_candidates.rds")
comparison_tbl <- readRDS("notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_vs_contiguity_comparison.rds")

cluster_zone_map_plot <- ggplot() +
  geom_sf(data = cluster_zones, aes(fill = cluster_order), color = "white", linewidth = 0.3, alpha = 0.9) +
  geom_sf(data = zone_inputs, fill = NA, color = "#4d4d4d", linewidth = 0.1, alpha = 0.25) +
  geom_text(
    data = sf::st_drop_geometry(cluster_zones),
    aes(x = label_lon, y = label_lat, label = cluster_label),
    size = 3.0,
    fontface = "bold"
  ) +
  scale_fill_viridis_c(option = "C", direction = -1) +
  theme_void() +
  labs(
    title = "Cluster Zones Map",
    subtitle = "Eligible tracts grouped by proximity-based clustering",
    fill = "Cluster order"
  )

cluster_summary_gt <- cluster_zone_summary %>%
  select(
    cluster_label,
    tracts,
    total_population,
    pop_growth_5yr_wtd,
    pop_density_median,
    units_per_1k_3yr_wtd,
    price_proxy_pctl_median,
    mean_tract_score,
    zone_area_sq_mi
  ) %>%
  arrange(cluster_label) %>%
  gt::gt() %>%
  gt::tab_header(title = "Cluster Zone Summary Metrics") %>%
  gt::cols_label(
    cluster_label = "Cluster Zone",
    tracts = "Tracts",
    total_population = "Population",
    pop_growth_5yr_wtd = "Pop growth (5y, wtd)",
    pop_density_median = "Median density",
    units_per_1k_3yr_wtd = "Units per 1k (wtd)",
    price_proxy_pctl_median = "Price proxy pctl",
    mean_tract_score = "Mean tract score",
    zone_area_sq_mi = "Area (sq mi)"
  ) %>%
  gt::fmt_number(columns = c(tracts, total_population), decimals = 0) %>%
  gt::fmt_percent(columns = c(pop_growth_5yr_wtd, price_proxy_pctl_median), decimals = 1) %>%
  gt::fmt_number(columns = c(pop_density_median, units_per_1k_3yr_wtd, mean_tract_score), decimals = 2) %>%
  gt::fmt_number(columns = zone_area_sq_mi, decimals = 1)

comparison_gt <- comparison_tbl %>%
  gt::gt() %>%
  gt::tab_header(title = "Contiguity vs Cluster Zones: Quick Comparison") %>%
  gt::cols_label(
    zone_type = "Zone Type",
    zone_count = "Zone Count",
    median_tracts_per_zone = "Median Tracts/Zone",
    mean_zone_score = "Mean Zone Score"
  ) %>%
  gt::fmt_number(columns = c(zone_count, median_tracts_per_zone), decimals = 0) %>%
  gt::fmt_number(columns = mean_zone_score, decimals = 3)

save_artifact(
  list(
    cluster_zone_map_plot = cluster_zone_map_plot,
    cluster_summary_gt = cluster_summary_gt,
    comparison_gt = comparison_gt
  ),
  "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_visual_objects.rds"
)

ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/04_zones/outputs/section_04_cluster_zone_map.png",
  plot = cluster_zone_map_plot,
  width = 9,
  height = 7,
  dpi = 150
)

message("Section 04 cluster visuals complete.")
