#' Rebase CBSA metrics from county-level data
#'
#' @param df Tibble with county-level observations including `cbsa_code`, `year`, and metric columns.
#' @param weight_col Column to use for weighting county contributions.
#'
#' @return A tibble summarising CBSA-level metrics.
#' @export
rebase_cbsa_from_counties <- function(df, weight_col = NULL) {
  stopifnot("cbsa_code" %in% names(df))
  stopifnot("year" %in% names(df))
  
  if (!is.null(weight_col)) {
    weight_sym <- rlang::sym(weight_col)
  } else {
    weight_sym <- rlang::sym("weight")
    df <- df |> dplyr::mutate(weight = 1)
  }
  
  numeric_cols <- names(dplyr::select(df, dplyr::where(is.numeric)))
  metric_cols <- setdiff(numeric_cols, rlang::as_string(weight_sym))
  
  df |>
    dplyr::group_by(cbsa_code, year) |>
    dplyr::summarise(
      dplyr::across(
        dplyr::all_of(metric_cols),
        ~stats::weighted.mean(.x, !!weight_sym, na.rm = TRUE)
      ),
      .groups = "drop"
    )
}