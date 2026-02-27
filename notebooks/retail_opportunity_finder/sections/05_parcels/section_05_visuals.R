# Section 05 visuals script
# Purpose: generate plots/tables from section outputs.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 05 visuals: 05_parcels")

zones_canonical <- readRDS("notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_zones_canonical.rds")
zone_overlay_contiguity <- readRDS("notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_zone_overlay_contiguity.rds")
zone_overlay_cluster <- readRDS("notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_zone_overlay_cluster.rds")
parcel_shortlist_contiguity <- readRDS("notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_parcel_shortlist_contiguity.rds")
parcel_shortlist_cluster <- readRDS("notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_parcel_shortlist_cluster.rds")

zone_overlay <- dplyr::bind_rows(zone_overlay_contiguity, zone_overlay_cluster)

zone_overlay_map_sf <- zones_canonical %>%
  left_join(
    zone_overlay %>% select(zone_system, zone_id, retail_area_density, retail_parcel_count, zone_quality_score),
    by = c("zone_system", "zone_id")
  )
analysis_crs_epsg <- if (!is.null(GEOMETRY_ASSUMPTIONS$analysis_crs_epsg)) GEOMETRY_ASSUMPTIONS$analysis_crs_epsg else 5070

build_zone_overlay_map <- function(zone_system_name, subtitle_text) {
  map_df <- zone_overlay_map_sf %>% filter(zone_system == zone_system_name)
  map_df_proj <- sf::st_transform(map_df, analysis_crs_epsg)
  label_geom <- sf::st_point_on_surface(sf::st_geometry(map_df_proj))
  label_pts <- sf::st_as_sf(map_df_proj %>% sf::st_drop_geometry(), geometry = label_geom, crs = analysis_crs_epsg) %>%
    sf::st_transform(sf::st_crs(map_df))
  label_xy <- cbind(
    sf::st_drop_geometry(map_df),
    sf::st_coordinates(label_pts)
  )

  ggplot() +
    geom_sf(
      data = map_df,
      aes(fill = retail_area_density),
      color = "white",
      linewidth = 0.3,
      alpha = 0.9
    ) +
    geom_text(
      data = label_xy,
      aes(x = X, y = Y, label = zone_label),
      size = 2.8,
      fontface = "bold"
    ) +
    scale_fill_viridis_c(option = "C", direction = 1, na.value = "#f0f0f0") +
    theme_void() +
    labs(
      title = paste0("Retail Area Density by Zone (", tools::toTitleCase(zone_system_name), ")"),
      subtitle = subtitle_text,
      fill = "Retail area\ndensity"
    )
}

build_shortlist_map <- function(shortlist_sf, zone_system_name) {
  zones <- zones_canonical %>% filter(zone_system == zone_system_name)
  top_points <- shortlist_sf %>%
    filter(shortlist_rank_system <= 200) %>%
    mutate(plot_weight = 1 / pmax(shortlist_rank_system, 1))
  top_points_proj <- sf::st_transform(top_points, analysis_crs_epsg)
  top_point_geom <- sf::st_point_on_surface(sf::st_geometry(top_points_proj))
  top_points <- sf::st_as_sf(top_points_proj %>% sf::st_drop_geometry(), geometry = top_point_geom, crs = analysis_crs_epsg) %>%
    sf::st_transform(sf::st_crs(shortlist_sf))

  ggplot() +
    geom_sf(data = zones, fill = NA, color = "#525252", linewidth = 0.4) +
    geom_sf(
      data = top_points,
      aes(color = shortlist_score, size = plot_weight),
      alpha = 0.65,
      show.legend = c(size = FALSE, color = TRUE)
    ) +
    scale_color_viridis_c(option = "D", direction = 1) +
    scale_size_continuous(range = c(0.8, 2.3)) +
    theme_void() +
    labs(
      title = paste0("Top Shortlisted Parcels (", tools::toTitleCase(zone_system_name), ")"),
      subtitle = "Top 200 parcels by system-level shortlist rank",
      color = "Shortlist\nscore"
    )
}

overlay_map_contiguity <- build_zone_overlay_map(
  "contiguity",
  "Cluster and contiguity systems are computed in parallel; this view is contiguity."
)
overlay_map_cluster <- build_zone_overlay_map(
  "cluster",
  "Default Section 05 narrative system."
)

shortlist_map_contiguity <- build_shortlist_map(parcel_shortlist_contiguity, "contiguity")
shortlist_map_cluster <- build_shortlist_map(parcel_shortlist_cluster, "cluster")

shortlist_table_contiguity <- parcel_shortlist_contiguity %>%
  sf::st_drop_geometry() %>%
  arrange(shortlist_rank_system) %>%
  slice_head(n = 50) %>%
  select(
    shortlist_rank_system,
    zone_label,
    parcel_uid,
    tract_geoid,
    retail_subtype,
    parcel_area_sqmi,
    assessed_value,
    zone_quality_score,
    local_retail_context_score,
    parcel_characteristics_score,
    shortlist_score
  ) %>%
  gt::gt() %>%
  gt::tab_header(title = "Top 50 Parcels - Contiguity System") %>%
  gt::fmt_number(
    columns = c(parcel_area_sqmi, zone_quality_score, local_retail_context_score, parcel_characteristics_score, shortlist_score),
    decimals = 3
  ) %>%
  gt::fmt_currency(columns = assessed_value, decimals = 0)

shortlist_table_cluster <- parcel_shortlist_cluster %>%
  sf::st_drop_geometry() %>%
  arrange(shortlist_rank_system) %>%
  slice_head(n = 50) %>%
  select(
    shortlist_rank_system,
    zone_label,
    parcel_uid,
    tract_geoid,
    retail_subtype,
    parcel_area_sqmi,
    assessed_value,
    zone_quality_score,
    local_retail_context_score,
    parcel_characteristics_score,
    shortlist_score
  ) %>%
  gt::gt() %>%
  gt::tab_header(title = "Top 50 Parcels - Cluster System") %>%
  gt::fmt_number(
    columns = c(parcel_area_sqmi, zone_quality_score, local_retail_context_score, parcel_characteristics_score, shortlist_score),
    decimals = 3
  ) %>%
  gt::fmt_currency(columns = assessed_value, decimals = 0)

system_comparison <- zone_overlay %>%
  group_by(zone_system) %>%
  summarise(
    zones = n_distinct(zone_id),
    retail_parcels = sum(retail_parcel_count, na.rm = TRUE),
    retail_area_total = sum(retail_area, na.rm = TRUE),
    avg_zone_quality = mean(zone_quality_score, na.rm = TRUE),
    avg_local_retail_context = mean(local_retail_context_score, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(zone_system = tools::toTitleCase(zone_system)) %>%
  arrange(zone_system)

system_comparison_gt <- system_comparison %>%
  gt::gt() %>%
  gt::tab_header(title = "Zone System Comparison") %>%
  gt::cols_label(
    zone_system = "Zone System",
    zones = "Zones",
    retail_parcels = "Retail Parcels",
    retail_area_total = "Retail Area (sq mi)",
    avg_zone_quality = "Avg Zone Quality",
    avg_local_retail_context = "Avg Local Retail Context"
  ) %>%
  gt::fmt_number(columns = c(zones, retail_parcels), decimals = 0) %>%
  gt::fmt_number(columns = c(retail_area_total, avg_zone_quality, avg_local_retail_context), decimals = 3)

save_artifact(
  list(
    overlay_map_contiguity = overlay_map_contiguity,
    overlay_map_cluster = overlay_map_cluster,
    shortlist_map_contiguity = shortlist_map_contiguity,
    shortlist_map_cluster = shortlist_map_cluster,
    shortlist_table_contiguity = shortlist_table_contiguity,
    shortlist_table_cluster = shortlist_table_cluster,
    system_comparison = system_comparison,
    system_comparison_gt = system_comparison_gt
  ),
  "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_visual_objects.rds"
)

ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_overlay_map_contiguity.png",
  plot = overlay_map_contiguity,
  width = 9,
  height = 7,
  dpi = 150
)
ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_overlay_map_cluster.png",
  plot = overlay_map_cluster,
  width = 9,
  height = 7,
  dpi = 150
)
ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_shortlist_map_contiguity.png",
  plot = shortlist_map_contiguity,
  width = 9,
  height = 7,
  dpi = 150
)
ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/05_parcels/outputs/section_05_shortlist_map_cluster.png",
  plot = shortlist_map_cluster,
  width = 9,
  height = 7,
  dpi = 150
)

message("Section 05 visuals complete.")
