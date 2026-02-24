# Section 03 visuals script
# Purpose: generate plots/tables from section outputs.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 03 visuals: 03_eligibility_scoring")

funnel_counts <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_funnel_counts.rds")
scored_tracts <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_scored_tracts.rds")
top_tracts <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_top_tracts.rds")
price_hist_input <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_price_hist_input.rds")
growth_hist_input <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_growth_hist_input.rds")
tract_sf <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_tract_sf.rds")
tract_component_scores <- readRDS("notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_tract_component_scores.rds")

funnel_gt <- funnel_counts %>%
  arrange(step_order) %>%
  mutate(
    pct_of_start = tracts_remaining / first(tracts_remaining)
  ) %>%
  select(step, tracts_remaining, pct_of_start) %>%
  gt::gt() %>%
  gt::tab_header(title = "Eligibility Funnel") %>%
  gt::cols_label(
    step = "Gate Step",
    tracts_remaining = "Tracts Remaining",
    pct_of_start = "% of Start"
  ) %>%
  gt::fmt_number(columns = tracts_remaining, decimals = 0) %>%
  gt::fmt_percent(columns = pct_of_start, decimals = 1)

price_hist_plot <- ggplot(price_hist_input, aes(x = price_proxy_pctl)) +
  geom_histogram(bins = 30, fill = "#4575b4", alpha = 0.8) +
  geom_vline(xintercept = MODEL_PARAMS$price_proxy_pctl_max, color = "#d73027", linetype = "dashed", linewidth = 1) +
  theme_minimal() +
  labs(
    title = "Price Proxy Percentile Distribution",
    subtitle = "Dashed line marks the v1 threshold",
    x = "Price proxy percentile",
    y = "Tract count"
  )

growth_median <- median(growth_hist_input$pop_growth_5yr, na.rm = TRUE)
growth_hist_plot <- ggplot(growth_hist_input, aes(x = pop_growth_5yr)) +
  geom_histogram(bins = 30, fill = "#1a9850", alpha = 0.8) +
  geom_vline(xintercept = growth_median, color = "#d73027", linetype = "dashed", linewidth = 1) +
  theme_minimal() +
  labs(
    title = "Population Growth (5y) Distribution",
    subtitle = "Dashed line marks median tract growth",
    x = "5-year population growth",
    y = "Tract count"
  )

eligible_map_plot <- ggplot(tract_sf) +
  geom_sf(aes(fill = factor(eligible_v1)), color = NA) +
  scale_fill_manual(values = c("0" = "#d9d9d9", "1" = "#2b8cbe"), labels = c("Ineligible", "Eligible")) +
  theme_void() +
  labs(
    title = "Eligible Tracts (v1)",
    fill = NULL
  )

score_hist_plot <- ggplot(scored_tracts, aes(x = tract_score)) +
  geom_histogram(bins = 30, fill = "#5e3c99", alpha = 0.85) +
  theme_minimal() +
  labs(
    title = "Tract Score Distribution (Eligible Tracts)",
    x = "Tract score",
    y = "Tract count"
  )

highlight_n <- min(20, nrow(scored_tracts))
top_highlight <- scored_tracts %>% slice_head(n = highlight_n)

growth_density_scatter <- ggplot(scored_tracts, aes(x = pop_density, y = pop_growth_5yr)) +
  geom_point(alpha = 0.25, color = "#636363") +
  geom_point(data = top_highlight, color = "#d73027", size = 2) +
  theme_minimal() +
  labs(
    title = "Growth vs Density (Eligible Tracts)",
    subtitle = paste0("Top ", highlight_n, " scored tracts highlighted"),
    x = "Population density",
    y = "Population growth (5y)"
  )

top_tracts_gt <- top_tracts %>%
  slice_head(n = 25) %>%
  gt::gt() %>%
  gt::tab_header(title = "Top 25 Tracts with Score Components") %>%
  gt::fmt_number(columns = c(tract_score, starts_with("contrib_")), decimals = 3) %>%
  gt::fmt_percent(columns = c(pop_growth_5yr, price_proxy_pctl), decimals = 1) %>%
  gt::fmt_number(columns = c(units_per_1k_3yr, pop_density, commute_intensity_b), decimals = 1)

component_score_table <- tract_component_scores %>%
  select(
    tract_geoid,
    eligible_v1,
    tract_rank,
    tract_score,
    z_growth,
    z_units,
    z_headroom,
    z_price,
    z_commute,
    contrib_growth,
    contrib_units,
    contrib_headroom,
    contrib_price,
    contrib_commute,
    why_tags
  )

save_artifact(
  list(
    funnel_gt = funnel_gt,
    price_hist_plot = price_hist_plot,
    growth_hist_plot = growth_hist_plot,
    eligible_map_plot = eligible_map_plot,
    score_hist_plot = score_hist_plot,
    growth_density_scatter = growth_density_scatter,
    top_tracts_gt = top_tracts_gt,
    component_score_table = component_score_table
  ),
  "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_visual_objects.rds"
)

ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_price_hist.png",
  plot = price_hist_plot,
  width = 8,
  height = 5,
  dpi = 150
)
ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_growth_hist.png",
  plot = growth_hist_plot,
  width = 8,
  height = 5,
  dpi = 150
)
ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_eligible_map.png",
  plot = eligible_map_plot,
  width = 8,
  height = 6,
  dpi = 150
)
ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_score_hist.png",
  plot = score_hist_plot,
  width = 8,
  height = 5,
  dpi = 150
)
ggplot2::ggsave(
  filename = "notebooks/retail_opportunity_finder/sections/03_eligibility_scoring/outputs/section_03_growth_density_scatter.png",
  plot = growth_density_scatter,
  width = 8,
  height = 5,
  dpi = 150
)

message("Section 03 visuals complete.")
