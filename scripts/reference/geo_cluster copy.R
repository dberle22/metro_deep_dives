library(tidyverse)
library(lubridate)
library(magrittr)
library(plotly)
library(tidytext)
library(scales)
library(tidycensus)
library(tigris)
library(sf)
library(readxl)
library(httr)
library(jsonlite)
library(DT)
library(ggbeeswarm)
library(knitr)
library(factoextra)
library(corrplot)
library(leaflet)
library(ggrepel)

# Geo Cluster ----
# **We need to start by defining our goals.**
#   For example:
#   
#   - Classify CBSAs into "market types" (e.g., growth, stagnating, volatile)
# - Discover peer metros for comparison or benchmarking
# - Segment markets for targeted investment strategies
# 
# Our goal will be to discover peer metros, for now.
# 
# **Select our model**
#   We will use K-Means
# 
# ## Variable Selection
# 
# ### Manual Selection
# **Economic Strength**
#   
#   - z_eco_wage_per_capita
# - z_eco_wage_growth_5yr
# - z_eco_unemployment_rate 
# - z_eco_unemployment_stability
# - z_eco_industry_entropy
# 
# **Housing Market**
#   
#   - z_housing_hpi_growth_5yr
# - z_housing_vacancy_rate
# - z_housing_units_per_capita
# - z_housing_permits_per_1000
# 
# **Population and Affordability**
#   
#   - z_pop_growth_5yr
# - z_pop_education_rate
# - z_afford_rental_index
# - z_afford_hud_rent_price_ratio
# - z_afford_rpp


## CBSA ----

### Variable selection ----

# Ingest Z Score KPIs
cbsa_kpi_scaled_z <- read_csv("Desktop/real_estate_investment/data/analytics/cbsa_scaled_z_kpi_core.csv")

cbsa_cluster_vars <- cbsa_kpi_scaled_z %>%
  select(z_eco_wage_per_worker, z_eco_wage_growth_5yr, z_eco_unemployment_rate, 
         z_eco_unemployment_stability, z_eco_industry_entropy, 
         z_housing_hpi_growth_5yr, z_housing_vacancy_rate, 
         z_housing_units_per_capita, z_housing_permits_per_1000, 
         z_pop_growth_5yr, z_pop_education_rate, z_afford_rental_index, 
         z_afford_hud_rent_price_ratio, z_afford_rpp)

### Create Elbow Plot ----
# Select the number of clusters here: 6
fviz_nbclust(cbsa_cluster_vars, kmeans, method = "wss")



### Run Clustering ----
# Example with k-means (choose your k)
set.seed(123)

kmeans_result <- kmeans(
  cbsa_cluster_vars,
  centers = 6,  # Replace with optimal k
  nstart = 25
)

# Add cluster labels back to your dataframe
cbsa_kpi_clustered <- cbsa_kpi_scaled_z %>%
  mutate(cluster = factor(kmeans_result$cluster))

### Analyze Clusters and create labels ----
cluster_summary_real <- cbsa_kpi_clustered %>%
  group_by(cluster) %>%
  summarise(across(
    .cols = matches("^(housing_|eco_|pop_|afford_)"),
    .fns = list(mean = ~ mean(.x, na.rm = TRUE)),
    .names = "{.col}_mean"
  )) %>%
  ungroup()

# Write the summary to a cvs 
write_csv(cluster_summary_real, "summary_cluster.csv")

# Add labels to and descriptions to our cluster df
kpi_clustered <- kpi_clustered %>%
  mutate(
    cluster_label = case_when(
      cluster == 1 ~ "Growth-Oriented Mid-Sized Markets",
      cluster == 2 ~ "Economically Struggling, High Growth Potential",
      cluster == 3 ~ "Small but Booming Markets",
      cluster == 4 ~ "Large, Expensive, Established Metros",
      cluster == 5 ~ "Declining or Stagnant Value Markets"
    ),
    cluster_description = case_when(
      cluster == 1 ~ "Fast-growing, relatively affordable metros with solid economic momentum and active housing development.",
      cluster == 2 ~ "Economically volatile smaller metros with potential upside from job recovery and undersupplied housing.",
      cluster == 3 ~ "Dynamic, high-income small metros likely driven by tech or innovation sectors with fast growth.",
      cluster == 4 ~ "Stable, wealthy major metros with high cost of entry and limited new supply, suited for long-term plays.",
      cluster == 5 ~ "Stagnant or declining metros with low costs but limited economic and population growth prospects."
    )
  )

### Write Cluster variables to CSV ----