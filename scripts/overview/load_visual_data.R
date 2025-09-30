# Read required data for visuals

# Make sure we're reading from the project Renviron
if (file.exists(".Renviron")) readRenviron(".Renviron")

# Set paths
analytics_env <- get_env_path("ANALYTICS")
benchmark_env <- get_env_path("ANALYTICS_BENCHMARKS")

# Overview metrics
cbsa_overview_snap <- readr::read_csv(file.path(analytics_env, "overview_cbsa_constant_latest.csv"), show_col_types = FALSE)
cbsa_overview_long <- readr::read_csv(file.path(analytics_env, "overview_cbsa_constant_long.csv"), show_col_types = FALSE)

# Benchmark Data
bm_nc <- readr::read_csv(file.path(benchmark_env, "bm_nc.csv"), show_col_types = FALSE)

bm_se <- readr::read_csv(file.path(benchmark_env, "bm_sc.csv"), show_col_types = FALSE)

bm_us <- readr::read_csv(file.path(benchmark_env, "bm_us.csv"), show_col_types = FALSE)