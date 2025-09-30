# Assemble a tidy table for 5y growth comparisons across four entities (Wilmington + 3 benchmarks)
metrics_map <- tibble::tibble(
  key = c("pop_chg_5y","gdp_chg_5y","gdp_per_cap_chg_5y","inc_per_cap_chg_5y"),
  label = factor(c("Population","Real GDP","GDP per Capita","Income per Capita"),
                 levels = c("Population","Real GDP","GDP per Capita","Income per Capita"))
)

vals <- tibble::tibble(
  entity = c("Wilmington","NC Metros Avg","SE Metros Avg","US Metros Avg"),
  pop_chg_5y = c(wilm_row$pop_chg_5y, bm_nc$pop_chg_5y, bm_se$pop_chg_5y, bm_us$pop_chg_5y),
  gdp_chg_5y = c(wilm_row$gdp_chg_5y, bm_nc$gdp_chg_5y, bm_se$gdp_chg_5y, bm_us$gdp_chg_5y),
  gdp_per_cap_chg_5y = c(wilm_row$gdp_pc_chg_5y, bm_nc$gdp_pc_chg_5y, bm_se$gdp_pc_chg_5y, bm_us$gdp_pc_chg_5y),
  inc_per_cap_chg_5y = c(wilm_row$inc_pc_chg_5y, bm_nc$inc_pc_chg_5y, bm_se$inc_pc_chg_5y, bm_us$inc_pc_chg_5y)
) %>%
  tidyr::pivot_longer(-entity, names_to = "key", values_to = "value") %>%
  dplyr::left_join(metrics_map, by = "key")

p_growth_bars <- vals %>%
  ggplot(aes(x = label, y = value, fill = entity)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
  scale_fill_viridis_d(option = "viridis", end = 0.9) +
  labs(title = "Five-Year Growth Comparison", x = NULL, y = "% Change", fill = NULL) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

p_growth_bars

# Export Visual
output_path <- get_env_path("OUTPUTS")

# Best: set both plot and legend backgrounds to white
p_growth_bars <- p_growth_bars +
  theme(
    plot.background   = element_rect(fill = "white", color = NA),
    panel.background  = element_rect(fill = "white", color = NA),
    legend.background = element_rect(fill = "white", color = NA),
    legend.key        = element_rect(fill = "white", color = NA)
  )

ggsave(paste0(output_path, "/overview/growth_bars.png")
  , p_growth_bars,
       width = 12, height = 8, dpi = 300,
       bg = "white",
       device = ragg::agg_png)