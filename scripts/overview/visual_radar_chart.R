# Z-score scaled radar (0–100 index), shown as 2x2 small multiples with a shared scale
# Reference distribution = all US metros in cbsa_metrics (latest year)

# 1) Build reference stats (means/sds) for each KPI across US metros
ref_stats <- cbsa_metrics %>%
  dplyr::filter(cbsa_type == "Metro Area") %>%
  dplyr::summarise(
    mu_pop   = mean(pop_cagr_5y,           na.rm = TRUE),
    sd_pop   = stats::sd(pop_cagr_5y,      na.rm = TRUE),
    mu_gdppc = mean(gdp_pc_cagr_5y,   na.rm = TRUE),
    sd_gdppc = stats::sd(gdp_pc_cagr_5y, na.rm = TRUE),
    mu_incpc = mean(inc_pc_cagr_5y,   na.rm = TRUE),
    sd_incpc = stats::sd(inc_pc_cagr_5y, na.rm = TRUE)
  )

# 2) Z -> 0–100 index helper (T-score style, clamped)
z_to_index <- function(x, mu, sd) {
  if (!is.finite(sd) || sd <= 0) return(rep(50, length(x)))
  idx <- 50 + 10 * ((x - mu) / sd)
  pmax(0, pmin(100, idx))
}

# 3) Assemble entities and transform to indices
radar_long <- tibble::tibble(
  entity = c("Wilmington","NC Metros Avg","SE Metros Avg","US Metros Avg"),
  `Population CAGR (5y)` = z_to_index(
    c(wilm_row$pop_cagr_5y, bm_nc$pop_cagr_5y, bm_se$pop_cagr_5y, bm_us$pop_cagr_5y),
    ref_stats$mu_pop, ref_stats$sd_pop
  ),
  `GDP per Capita CAGR (5y)` = z_to_index(
    c(wilm_row$gdp_pc_cagr_5y, bm_nc$gdp_pc_cagr_5y, bm_se$gdp_pc_cagr_5y, bm_us$gdp_pc_cagr_5y),
    ref_stats$mu_gdppc, ref_stats$sd_gdppc
  ),
  `Income per Capita CAGR (5y)` = z_to_index(
    c(wilm_row$inc_pc_cagr_5y, bm_nc$inc_pc_cagr_5y, bm_se$inc_pc_cagr_5y, bm_us$inc_pc_cagr_5y),
    ref_stats$mu_incpc, ref_stats$sd_incpc
  )
)

# 4) Draw 2x2 small multiples with unified 0–100 scale
max_row <- radar_long %>% dplyr::select(-entity) %>% dplyr::summarise(dplyr::across(everything(), ~100))
min_row <- radar_long %>% dplyr::select(-entity) %>% dplyr::summarise(dplyr::across(everything(), ~0))
cols <- viridis::viridis(4, end = 0.9)

op <- par(mfrow = c(2,2), mar = c(2,2,3,2))
for (i in seq_len(nrow(radar_long))) {
  ent <- radar_long$entity[i]
  dat <- radar_long %>% dplyr::filter(entity == ent) %>% dplyr::select(-entity)
  plot_df <- dplyr::bind_rows(max_row, min_row, dat) %>% as.data.frame()
  fmsb::radarchart(
    plot_df,
    axistype = 1,
    seg = 5,
    caxislabels = seq(0, 100, by = 20),
    pcol = cols[i],
    pfcol = scales::alpha(cols[i], 0.25),
    plwd = 2,
    pty = 16,
    cglwd = 0.8,
    cglcol = "grey80",
    vlcex = 0.9,
    axislabcol = "grey30",
    title = ent
  )
}
par(op)

# Export to Outputs folder
# Export Visual
output_path <- get_env_path("OUTPUTS")

# Best: set both plot and legend backgrounds to white
op <- op +
  theme(
    plot.background   = element_rect(fill = "white", color = NA),
    panel.background  = element_rect(fill = "white", color = NA),
    legend.background = element_rect(fill = "white", color = NA),
    legend.key        = element_rect(fill = "white", color = NA)
  )

ggsave(paste0(output_path, "/overview/radar_chart.png")
       , op,
       width = 12, height = 8, dpi = 300,
       bg = "white",
       device = ragg::agg_png)