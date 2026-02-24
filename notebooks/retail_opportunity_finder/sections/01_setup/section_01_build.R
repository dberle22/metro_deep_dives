# Section 01 build script
# Purpose: data prep and core transformations for section 01_setup.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running section 01 build: 01_setup")

project_root <- resolve_project_root()
model_params_check <- validate_model_params(MODEL_PARAMS)
run_meta <- run_metadata()

foundation_payload <- list(
  run_metadata = run_meta,
  project_root = project_root,
  model_params = MODEL_PARAMS,
  model_params_check = model_params_check,
  kpi_dictionary = KPI_DICTIONARY,
  generated_at = as.character(Sys.time())
)

save_artifact(
  run_meta,
  "notebooks/retail_opportunity_finder/sections/01_setup/outputs/section_01_run_metadata.rds"
)

save_artifact(
  foundation_payload,
  "notebooks/retail_opportunity_finder/sections/01_setup/outputs/section_01_foundation.rds"
)

message("Section 01 build complete.")
