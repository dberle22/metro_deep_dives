
library(gt)

# Create our Target Geo DF
w <- cbsa_overview_snap %>% 
  filter(cbsa_geoid == target_geoid) %>%
  dplyr::select(
  pop_chg_5y, gdp_chg_5y, gdp_pc_chg_5y, inc_chg_5y, inc_pc_chg_5y,
  pop_cagr_5y, gdp_cagr_5y, gdp_pc_cagr_5y, inc_cagr_5y, inc_pc_cagr_5y
)

# Build the Overview Table and save it
overview_tbl <- tibble::tibble(
  Metric = c(
    "Population Growth (5y)","Real GDP Growth (5y)", "GDP Per Capita Growth (5y)",
    "Personal Income Growth (5y)", "Income Per Capita Growth (5y)",
    "Population CAGR (5y)","Real GDP CAGR (5y)", "GDP Per Capita CAGR (5y)",
    "Personal Income CAGR (5y)", "Income Per Capita CAGR (5y)"
  ),
  Wilmington = c(
    w$pop_chg_5y, w$gdp_chg_5y, w$gdp_pc_chg_5y, w$inc_chg_5y, w$inc_pc_chg_5y,
    w$pop_cagr_5y, w$gdp_cagr_5y, w$gdp_pc_cagr_5y, w$inc_cagr_5y, w$inc_pc_cagr_5y
  ),
  `NC Metros Avg` = c(
    bm_nc$pop_chg_5y, bm_nc$gdp_chg_5y, bm_nc$gdp_pc_chg_5y, bm_nc$inc_chg_5y, bm_nc$inc_pc_chg_5y,
    bm_nc$pop_cagr_5y, bm_nc$gdp_cagr_5y, bm_nc$gdp_pc_cagr_5y, bm_nc$inc_cagr_5y, bm_nc$inc_pc_cagr_5y
  ),
  `SE Metros Avg` = c(
    bm_se$pop_chg_5y, bm_se$gdp_chg_5y, bm_se$gdp_pc_chg_5y, bm_se$inc_chg_5y, bm_se$inc_pc_chg_5y,
    bm_se$pop_cagr_5y, bm_se$gdp_cagr_5y, bm_se$gdp_pc_cagr_5y, bm_se$inc_cagr_5y, bm_se$inc_pc_cagr_5y
  ),
  `US Metros Avg` = c(
    bm_us$pop_chg_5y, bm_us$gdp_chg_5y, bm_us$gdp_pc_chg_5y, bm_us$inc_chg_5y, bm_us$inc_pc_chg_5y,
    bm_us$pop_cagr_5y, bm_us$gdp_cagr_5y, bm_us$gdp_pc_cagr_5y, bm_us$inc_cagr_5y, bm_us$inc_pc_cagr_5y
  )
) %>% dplyr::mutate(across(-Metric, ~ pct(.)))

overview_tbl

# Reformat table for nice visuals
gt_tbl <- overview_tbl %>%
  gt() %>%
  fmt_percent(columns = c(Wilmington, `NC Metros Avg`, `SE Metros Avg`, `US Metros Avg`), decimals = 1) %>%
  cols_align(align = "left", columns = c(Metric)) %>%
  cols_width(
    Metric ~ px(260),
    everything() ~ px(150)
  ) %>%
  tab_header(
    title = md(glue::glue("**{metro_name} — Overview KPIs (5y)**")),
    subtitle = glue::glue("{min(analysis_years)}–{max(analysis_years)} · Constant-geometry (2023 counties)")
  ) %>%
  tab_options(
    table.font.size = px(12),
    data_row.padding = px(4),
    table.background.color = "white"
  )

gt_tbl

# Export the visual
gt::gtsave(gt_tbl, paste0(output_path, "/overview/growth_table.png"),
           vwidth = 1400, vheight = 900, expand = 5, path = ".")