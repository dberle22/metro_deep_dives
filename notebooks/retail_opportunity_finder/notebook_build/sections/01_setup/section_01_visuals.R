# Notebook-build Section 01 visuals
# Purpose: Emit a minimal visual payload for setup metadata.

source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running notebook_build section 01 visuals: 01_setup")

foundation_payload <- readRDS(read_artifact_path("01_setup", "section_01_foundation"))

visual_objects <- list(
  setup_summary = tibble::tibble(
    market_key = foundation_payload$market_profile$market_key,
    market_name = foundation_payload$market_profile$market_name,
    cbsa_code = foundation_payload$market_profile$cbsa_code,
    generated_at = foundation_payload$generated_at
  )
)

save_artifact(
  visual_objects,
  resolve_output_path("01_setup", "section_01_visual_objects")
)

message("Notebook-build Section 01 visuals complete.")
