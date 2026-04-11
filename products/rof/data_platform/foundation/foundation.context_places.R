resolve_foundation_context_places_path <- function() {
  path <- "notebooks/retail_opportunity_finder/sections/02_market_overview/context_layers/outputs/section_02_context_places_sf.rds"
  if (!file.exists(path)) {
    stop(sprintf("Context artifact not found: %s", path), call. = FALSE)
  }
  path
}

read_foundation_context_places <- function() {
  readRDS(resolve_foundation_context_places_path())
}
