states_sf <- tigris::states(class = "sf")
se_sc_states <- c("FL","GA","SC","NC","TN","AL","MS","AR","LA","TX","OK","VA","WV","KY")

cbsa_geo <- core_based_statistical_areas(year = 2023, class = "sf") %>%
  janitor::clean_names() %>%
  dplyr::transmute(geoid = cbsafp, NAME = name, geometry)

cbsa_metrics <- cbsa_const_snap %>%
  dplyr::group_by(division) %>%
  dplyr::mutate(reg_rank_in_cbsa_type = rank(-pop_cagr_5y, ties.method = "first"),
                cbsa_geoid = as.character(cbsa_geoid)) %>%
  dplyr::ungroup()

plot_crs <- 5070
states_se <- states_sf %>% dplyr::filter(STUSPS %in% se_sc_states) %>% sf::st_transform(plot_crs)

cbsa_sf <- cbsa_geo %>%
  dplyr::left_join(cbsa_metrics, by = c("geoid" = "cbsa_geoid")) %>%
  dplyr::filter(primary_state %in% se_sc_states, cbsa_type == "Metro Area", !is.na(pop_cagr_5y)) %>%
  sf::st_transform(plot_crs)

cbsa_q <- cbsa_sf %>%
  dplyr::mutate(
    growth_q5 = dplyr::ntile(pop_cagr_5y, 5),
    growth_q5_lbl = factor(growth_q5, levels = 1:5,
                           labels = c("Bottom 20%","20–40%","40–60%","60–80%","Top 20%"))
  )

# Always include a label for the target CBSA
labs_top <- cbsa_q %>%
  dplyr::filter(!is.na(reg_rank_in_cbsa_type)) %>%
  dplyr::slice_min(order_by = reg_rank_in_cbsa_type, n = 10, with_ties = FALSE)

labs_target <- cbsa_q %>%
  dplyr::filter(geoid == .env$target_geoid) %>%
  dplyr::mutate(label_pt = sf::st_point_on_surface(geometry),
                coords = sf::st_coordinates(label_pt), x = coords[,1], y = coords[,2])

labs_df <- labs_top %>%
  dplyr::mutate(label_pt = sf::st_point_on_surface(geometry),
                coords = sf::st_coordinates(label_pt), x = coords[,1], y = coords[,2]) %>%
  dplyr::bind_rows(labs_target) %>%
  dplyr::distinct(geoid, .keep_all = TRUE)

# Regional map bounds
bb_reg <- sf::st_bbox(states_se); xlim_reg <- c(bb_reg["xmin"], bb_reg["xmax"]); ylim_reg <- c(bb_reg["ymin"], bb_reg["ymax"])

# Target geometry for highlight
target_sf <- cbsa_q %>% dplyr::filter(geoid == .env$cbsa_geoid)

# Regional map with target highlight
p_q_region <- ggplot() +
  geom_sf(data = cbsa_q, aes(fill = growth_q5_lbl), color = "white", linewidth = 0.22, alpha = 0.9) +
  geom_sf(data = states_se, fill = NA, color = "white", linewidth = 0.7) +
  geom_sf(data = states_se, fill = NA, color = "grey30", linewidth = 0.35) +
  geom_sf(data = cbsa_q, fill = NA, color = "grey25", linewidth = 0.16) +
  # bold highlight for target
  geom_sf(data = target_sf, fill = NA, color = "black", linewidth = 0.9) +
  geom_sf(data = target_sf, fill = NA, color = "#FDE725", linewidth = 0.6) +
  ggrepel::geom_label_repel(
    data = labs_df, aes(x = x, y = y, label = NAME), size = 3, seed = 123,
    fill = scales::alpha("white", 0.75), label.size = 0.2,
    min.segment.length = 0, max.overlaps = Inf
  ) +
  # ensure target label is present and emphasized
  ggrepel::geom_label_repel(
    data = labs_target, aes(x = x, y = y, label = NAME), size = 3.2, seed = 123,
    fill = scales::alpha("#FFF3", 0.9), label.size = 0.3, fontface = "bold",
    min.segment.length = 0, max.overlaps = Inf
  ) +
  scale_fill_viridis_d(option = "viridis", direction = 1, name = "Pop Growth Quintile") +
  coord_sf(xlim = xlim_reg, ylim = ylim_reg, expand = FALSE, clip = "on") +
  labs(title = "Southeast/South Central — CBSA Population Growth (Quintiles)",
       subtitle = "Fill: Quintiles of Pop CAGR (5y). Bold outline = Target CBSA; labels include Top 10 + Target") +
  theme_minimal(base_size = 11) +
  theme(axis.text = element_blank(), axis.title = element_blank(), axis.ticks = element_blank(), panel.grid = element_blank(),
        legend.title = element_text(face = "bold"))

p_q_region

# Let's also create a version limited to the selected state
primary_state_code <- cbsa_metrics %>%
  filter(cbsa_geoid == target_geoid) %>%
  .$primary_state
states_state <- states_sf %>% dplyr::filter(STUSPS == primary_state_code) %>% sf::st_transform(plot_crs)
cbsa_state <- cbsa_q %>% dplyr::filter(primary_state == primary_state_code)

# Use the same (regional) quintile bins; just filter to state
cbsa_state_q <- cbsa_q %>%
  dplyr::filter(primary_state == primary_state_code)

labs_state <- cbsa_state_q %>%
  dplyr::mutate(label_pt = sf::st_point_on_surface(geometry),
                coords = sf::st_coordinates(label_pt), x = coords[,1], y = coords[,2])

labs_state_target <- labs_state %>% dplyr::filter(geoid == .env$cbsa_geoid)

bb_st <- sf::st_bbox(states_state); xlim_st <- c(bb_st["xmin"], bb_st["xmax"]); ylim_st <- c(bb_st["ymin"], bb_st["ymax"])

p_q_state <- ggplot() +
  geom_sf(data = cbsa_state_q, aes(fill = growth_q5_lbl), color = "white", linewidth = 0.28, alpha = 0.9) +
  geom_sf(data = states_state, fill = NA, color = "white", linewidth = 0.7) +
  geom_sf(data = states_state, fill = NA, color = "grey30", linewidth = 0.35) +
  geom_sf(data = cbsa_state_q, fill = NA, color = "grey25", linewidth = 0.16) +
  geom_sf(data = target_sf, fill = NA, color = "black", linewidth = 1.0) +
  geom_sf(data = target_sf, fill = NA, color = "#FDE725", linewidth = 0.7) +
  ggrepel::geom_label_repel(
    data = labs_state, aes(x = x, y = y, label = NAME), size = 3, seed = 123,
    fill = scales::alpha("white", 0.75), label.size = 0.2,
    min.segment.length = 0, max.overlaps = Inf
  ) +
  ggrepel::geom_label_repel(
    data = labs_state_target, aes(x = x, y = y, label = NAME), size = 3.2, seed = 123,
    fill = scales::alpha("#FFF3", 0.9), label.size = 0.3, fontface = "bold",
    min.segment.length = 0, max.overlaps = Inf
  ) +
  scale_fill_viridis_d(option = "viridis", direction = 1, name = "Pop Growth Quintile") +
  coord_sf(xlim = xlim_st, ylim = ylim_st, expand = FALSE, clip = "on") +
  labs(title = glue::glue("{primary_state_code} — CBSA Population Growth (Quintiles)"),
       subtitle = "Fill: Quintiles of Pop CAGR (5y). Bold outline = Target CBSA") +
  theme_minimal(base_size = 11) +
  theme(axis.text = element_blank(), axis.title = element_blank(), axis.ticks = element_blank(), panel.grid = element_blank(),
        legend.title = element_text(face = "bold"))

p_q_state

# Display both
p_q_region
p_q_state



# Export Visual
output_path <- get_env_path("OUTPUTS")

# Best: set both plot and legend backgrounds to white
# Region
p_q_region <- p_q_region +
  theme(
    plot.background   = element_rect(fill = "white", color = NA),
    panel.background  = element_rect(fill = "white", color = NA),
    legend.background = element_rect(fill = "white", color = NA),
    legend.key        = element_rect(fill = "white", color = NA)
  )

ggsave(paste0(output_path, "/overview/regional_map.png")
       , p_q_region,
       width = 12, height = 8, dpi = 300,
       bg = "white",
       device = ragg::agg_png)

# State
p_q_state <- p_q_state +
  theme(
    plot.background   = element_rect(fill = "white", color = NA),
    panel.background  = element_rect(fill = "white", color = NA),
    legend.background = element_rect(fill = "white", color = NA),
    legend.key        = element_rect(fill = "white", color = NA)
  )

ggsave(paste0(output_path, "/overview/state_map.png")
       , p_q_state,
       width = 12, height = 8, dpi = 300,
       bg = "white",
       device = ragg::agg_png)
