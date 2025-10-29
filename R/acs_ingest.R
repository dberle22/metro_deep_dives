#' Simple multi-year ACS ingester (tidycensus)
#' @param geography Character; e.g., "us", "state", "county", "tract", etc.
#' @param years Integer vector; e.g., 2012:2023
#' @param variables Named character vector (names = your column names; values = ACS codes)
#' @param state Optional; required for tract pulls (string or vector of state abbreviations/FIPS)
#' @param survey "acs5" (default) or "acs1"
#' @param output "wide" (default) or "tidy"
#' @param geometry FALSE by default for faster ingestion
#' @param ... Any other args passed to tidycensus::get_acs()
#' @return A data.frame/tibble with a `year` column appended.
acs_ingest <- function(
    geography,
    years,
    variables,
    state    = NULL,
    survey   = "acs5",
    output   = "wide",
    geometry = FALSE,
    ...
) {
  # light guardrail for tract-level pulls
  if (is.null(state) && tolower(geography) %in% c("tract", "block group")) {
    stop("For geography='", geography, "', please provide `state` (can be a single value or vector).")
  }
  
  purrr::map_dfr(years, function(y) {
    # build args and include `state` only when provided and relevant
    args <- list(
      geography = geography,
      variables = variables,
      survey    = survey,
      year      = y,
      output    = output,
      geometry  = geometry,
      ...
    )
    
    if (!is.null(state) && tolower(geography) %in% c("tract", "block group", "county subdivision", "place")) {
      args$state <- state
    }
    
    do.call(tidycensus::get_acs, args) %>%
      dplyr::mutate(year = y, .after = 1)
  })
}