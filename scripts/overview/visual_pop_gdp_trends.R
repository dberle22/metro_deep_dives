# Population & GDP trends (levels) for the target CBSA
# Create Wilm Series

target_series <- cbsa_const_long %>%
  filter(cbsa_geoid == target_geoid)

p_pop <- target_series %>%
  ggplot(aes(year, population)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_x_continuous(
    breaks = seq(min(analysis_years), max(analysis_years), by = 1),
    limits = c(min(analysis_years), max(analysis_years)),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    labels = scales::label_number(scale_cut = scales::cut_short_scale()),
    limits = c(0, NA),
    expand = expansion(mult = c(0, 0.05))
  ) +
  labs(
    title = glue::glue("{metro_name}: Population Trend ({min(analysis_years)}–{max(analysis_years)})"),
    x = NULL, y = "Population"
  ) +
  theme_minimal(base_size = 12)

p_pop

p_gdp <- target_series %>%
  ggplot(aes(year, gdp_thousands)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_x_continuous(
    breaks = seq(min(analysis_years), max(analysis_years), by = 1),
    limits = c(min(analysis_years), max(analysis_years)),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    labels = scales::label_number(accuracy = 1, big.mark = ","),
    limits = c(0, NA),
    expand = expansion(mult = c(0, 0.05))
  ) +
  labs(
    title = glue::glue("{metro_name}: Real GDP (Chained 2017$) Trend ({min(analysis_years)}–{max(analysis_years)})"),
    x = NULL, y = "GDP (Thousands)"
  ) +
  theme_minimal(base_size = 12)

p_gdp

# Create side-by-side
p_trends_side_by_side <- p_pop | p_gdp

p_trends_side_by_side

# Export to Outputs folder
# Export Visual
output_path <- get_env_path("OUTPUTS")

# Best: set both plot and legend backgrounds to white
p_trends_side_by_side <- p_trends_side_by_side +
  theme(
    plot.background   = element_rect(fill = "white", color = NA),
    panel.background  = element_rect(fill = "white", color = NA),
    legend.background = element_rect(fill = "white", color = NA),
    legend.key        = element_rect(fill = "white", color = NA)
  )

ggsave(paste0(output_path, "/overview/trends_side_by_side.png")
       , p_trends_side_by_side,
       width = 12, height = 8, dpi = 300,
       bg = "white",
       device = ragg::agg_png)