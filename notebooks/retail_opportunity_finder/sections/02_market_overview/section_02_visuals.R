# Section 02 visuals script
# Purpose: generate plots/tables from section outputs.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 02 visuals: 02_market_overview")

kpi_tiles <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_kpi_tiles.rds")
peer_table <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_peer_table.rds")
benchmark_table <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_benchmark_table.rds")
pop_trend_indexed <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_pop_trend_indexed.rds")
distribution_long <- readRDS("notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_distribution_long.rds")

kpi_tile <- function(label, value, subtitle = NULL) {
  bslib::card(
    bslib::card_body(
      htmltools::tags$div(style = "font-size: 12px; color: #666;", label),
      htmltools::tags$div(style = "font-size: 28px; font-weight: 700; line-height: 1.1;", value),
      if (!is.null(subtitle)) htmltools::tags$div(style = "font-size: 11px; color: #888; margin-top: 6px;", subtitle)
    ),
    style = "height: 120px;"
  )
}

tiles_ui <- list(
  kpi_tile("Population (2024)", kpi_tiles$population_fmt),
  kpi_tile("Pop growth (5y)", kpi_tiles$pop_growth_5yr_fmt, "2019→2024 (ACS 5-year)"),
  kpi_tile("Units per 1k (3y avg)", kpi_tiles$units_per_1k_3yr_fmt, "BPS rolling avg"),
  kpi_tile("Median rent", kpi_tiles$median_rent_fmt),
  kpi_tile("Median home value", kpi_tiles$median_home_value_fmt),
  kpi_tile("Mean commute", kpi_tiles$mean_commute_min_fmt)
)

tiles_layout <- bslib::layout_column_wrap(width = 1 / 3, !!!tiles_ui)

peer_gt <- peer_table %>%
  arrange(pop_growth_rank) %>%
  gt::gt(rowname_col = "metro_name") %>%
  gt::tab_header(title = "Peer context: ranks and raw values (2024)") %>%
  gt::cols_label(
    pop_growth_rank = "Growth rank",
    pop_growth_5yr = "Pop growth (5y)",
    units_per_1k_rank = "Units rank",
    units_per_1k_3yr = "Units/1k (3y)",
    median_rent_rank = "Rent rank",
    median_rent = "Median rent",
    home_value_rank = "Home value rank",
    median_home_value = "Median home value",
    mean_travel_time_rank = "Commute rank",
    mean_travel_time = "Mean commute"
  ) %>%
  gt::fmt_percent(columns = pop_growth_5yr, decimals = 1) %>%
  gt::fmt_number(columns = units_per_1k_3yr, decimals = 1) %>%
  gt::fmt_currency(columns = c(median_rent, median_home_value), currency = "USD", decimals = 0) %>%
  gt::fmt_number(columns = mean_travel_time, decimals = 1, suffixing = FALSE) %>%
  gt::fmt(columns = mean_travel_time, fns = function(x) paste0(x, " min")) %>%
  gt::cols_align(align = "center", columns = ends_with("_rank")) %>%
  gt::cols_align(align = "right", columns = c(pop_growth_5yr, units_per_1k_3yr, median_rent, median_home_value, mean_travel_time)) %>%
  gt::tab_options(table.font.size = 12, data_row.padding = gt::px(3), column_labels.font.weight = "600")

benchmark_gt <- benchmark_table %>%
  select(
    geo_name,
    population,
    pop_growth_5yr,
    units_per_1k_3yr,
    median_gross_rent,
    median_home_value,
    mean_travel_time
  ) %>%
  gt::gt(rowname_col = "geo_name") %>%
  gt::tab_header(title = "Benchmark comparison: Jacksonville vs region vs US (2024)") %>%
  gt::tab_spanner(label = "Demand", columns = c(population, pop_growth_5yr)) %>%
  gt::tab_spanner(label = "Supply", columns = c(units_per_1k_3yr)) %>%
  gt::tab_spanner(label = "Housing costs", columns = c(median_gross_rent, median_home_value)) %>%
  gt::tab_spanner(label = "Mobility", columns = c(mean_travel_time)) %>%
  gt::fmt_number(columns = population, decimals = 0) %>%
  gt::fmt_percent(columns = pop_growth_5yr, decimals = 1) %>%
  gt::fmt_number(columns = units_per_1k_3yr, decimals = 1) %>%
  gt::fmt_currency(columns = c(median_gross_rent, median_home_value), currency = "USD", decimals = 0) %>%
  gt::fmt_number(columns = mean_travel_time, decimals = 1) %>%
  gt::fmt(columns = mean_travel_time, fns = function(x) paste0(x, " min")) %>%
  gt::tab_options(table.font.size = 12, data_row.padding = gt::px(4), column_labels.font.weight = "600")

baseline_year <- pop_trend_indexed %>%
  summarise(b = min(year[abs(pop_index - 100) < 1e-9], na.rm = TRUE)) %>%
  pull(b)

pop_trend_plot <- ggplot(pop_trend_indexed, aes(x = year, y = pop_index, color = geo)) +
  geom_line(linewidth = 1) +
  theme_minimal() +
  ggplot2::scale_x_continuous(
    breaks = scales::pretty_breaks(n = 6),
    labels = function(x) paste0(x, " 5yr")
  ) +
  labs(
    title = "Population trend (indexed to 100 at baseline)",
    subtitle = paste0("Baseline year: ", baseline_year, " (ACS 5-year vintages)"),
    x = NULL,
    y = "Population index",
    color = NULL
  )

jax_points <- distribution_long %>% filter(is_jax)

distribution_plot <- ggplot(distribution_long, aes(x = metric_label, y = value_plot)) +
  geom_boxplot(outlier.shape = NA) +
  geom_jitter(width = 0.10, alpha = 0.12, size = 1) +
  geom_point(data = jax_points, aes(x = metric_label, y = value_plot), size = 3) +
  geom_text(data = jax_points, aes(x = metric_label, y = value_plot, label = "JAX"), vjust = -0.8, size = 3) +
  facet_wrap(~ metric_label, scales = "free_y", nrow = 2) +
  theme_minimal() +
  theme(
    axis.title.x = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    strip.text = element_text(face = "bold"),
    legend.position = "none"
  ) +
  labs(
    title = "Where Jacksonville sits vs all U.S. metros (2024)",
    subtitle = "Distributions across all CBSAs (metros only). Jacksonville highlighted.",
    y = NULL,
    caption = "Distribution across all CBSAs. Jacksonville highlighted."
  )

save_artifact(
  list(
    tiles_layout = tiles_layout,
    peer_gt = peer_gt,
    benchmark_gt = benchmark_gt,
    pop_trend_plot = pop_trend_plot,
    distribution_plot = distribution_plot
  ),
  "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_visual_objects.rds"
)

ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_pop_trend_plot.png",
  plot = pop_trend_plot,
  width = 9,
  height = 5,
  dpi = 150
)

ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/02_market_overview/outputs/section_02_distribution_plot.png",
  plot = distribution_plot,
  width = 10,
  height = 6,
  dpi = 150
)

message("Section 02 visuals complete.")
