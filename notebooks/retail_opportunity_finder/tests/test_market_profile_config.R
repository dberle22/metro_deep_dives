source("notebooks/retail_opportunity_finder/sections/_shared/bootstrap.R")
initialize_section_runtime()

message("Running market profile config checks")

profile_results <- lapply(MARKET_PROFILES, validate_market_profile)
profile_pass <- all(vapply(profile_results, `[[`, logical(1), "pass"))

profile_names_match <- setequal(
  names(MARKET_PROFILES),
  unname(vapply(MARKET_PROFILES, `[[`, character(1), "market_key"))
)

active_profile <- get_market_profile()
active_profile_matches_target <- identical(active_profile$cbsa_code, TARGET_CBSA)

all_peer_sets_include_target <- all(vapply(
  MARKET_PROFILES,
  function(profile) profile$cbsa_code %in% profile$peers,
  logical(1)
))

all_state_scopes_unique <- all(vapply(
  MARKET_PROFILES,
  function(profile) length(unique(profile$state_scope)) == length(profile$state_scope),
  logical(1)
))

jacksonville_profile <- MARKET_PROFILES[["jacksonville_fl"]]
jacksonville_tract_table <- resolve_tract_geometry_table(jacksonville_profile)
jacksonville_query <- build_tract_geometry_query(jacksonville_profile)

florida_geometry_resolution_ok <- identical(
  jacksonville_tract_table,
  GEOMETRY_SOURCE_REGISTRY$tract_tables[["FL"]]
) && grepl(jacksonville_tract_table, jacksonville_query, fixed = TRUE)

southeast_geometry_resolution_ok <- identical(
  resolve_tract_geometry_table(MARKET_PROFILES[["savannah_ga"]]),
  GEOMETRY_SOURCE_REGISTRY$tract_tables[["GA"]]
) && identical(
  resolve_tract_geometry_table(MARKET_PROFILES[["greenville_sc"]]),
  GEOMETRY_SOURCE_REGISTRY$tract_tables[["SC"]]
) && identical(
  resolve_tract_geometry_table(MARKET_PROFILES[["wilmington_nc"]]),
  GEOMETRY_SOURCE_REGISTRY$tract_tables[["NC"]]
)

unsupported_profile <- list(
  market_key = "richmond_va",
  cbsa_code = "40060",
  state_scope = c("VA")
)

unsupported_error <- tryCatch(
  {
    resolve_tract_geometry_table(unsupported_profile)
    NULL
  },
  error = function(e) conditionMessage(e)
)

unsupported_geometry_error_ok <- is.character(unsupported_error) &&
  grepl("Unsupported tract geometry source", unsupported_error, fixed = TRUE) &&
  grepl("richmond_va", unsupported_error, fixed = TRUE) &&
  grepl("state_scope=VA", unsupported_error, fixed = TRUE) &&
  grepl("FL", unsupported_error, fixed = TRUE)

all_pass <- profile_pass &&
  profile_names_match &&
  active_profile_matches_target &&
  all_peer_sets_include_target &&
  all_state_scopes_unique &&
  florida_geometry_resolution_ok &&
  southeast_geometry_resolution_ok &&
  unsupported_geometry_error_ok

if (!all_pass) {
  stop("Market profile config checks failed.", call. = FALSE)
}

message("Market profile config checks complete.")
