suppressPackageStartupMessages({
  library(yaml)
})

std_key_cols <- c("geo_level", "geo_id", "geo_name", "year", "period", "table")

is_missing_text <- function(x) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) return(TRUE)
  x <- trimws(as.character(x)[1])
  x == ""
}

classify_definition_strength <- function(definition, needs_confirmation = NULL) {
  d <- if (is_missing_text(definition)) "" else trimws(as.character(definition)[1])
  if (d == "" || grepl("definition not yet documented", d, ignore.case = TRUE)) return("undefined")
  if (grepl("metric from .*acs table", d, ignore.case = TRUE)) return("weak")
  if (grepl("needs confirmation", d, ignore.case = TRUE)) return("weak")
  if (!is.null(needs_confirmation) && isTRUE(needs_confirmation)) return("weak")
  "strong"
}

normalize_metric_key <- function(x) {
  x <- as.character(x)
  # median_age.E -> median_age ; pop_totalE -> pop_total
  x <- sub("\\.[EeMm]$", "", x)
  x <- sub("[EeMm]$", "", x)
  x
}

script_stem_for_theme <- function(theme) {
  m <- c(
    age = "age",
    education = "edu",
    housing = "housing",
    income = "income",
    labor = "labor",
    migration = "migration",
    race = "race",
    transport = "transport"
  )
  if (!theme %in% names(m)) return(theme)
  unname(m[theme])
}

extract_block <- function(lines, start_idx) {
  buf <- character()
  i <- start_idx
  while (i <= length(lines)) {
    ln <- lines[[i]]
    buf <- c(buf, ln)
    if (i > start_idx && grepl("^\\s*\\)\\s*$", ln)) break
    i <- i + 1L
  }
  list(text = paste(buf, collapse = "\n"), end_idx = i)
}

extract_var_map_from_staging_script <- function(script_path) {
  if (!file.exists(script_path)) {
    return(data.frame(metric_key = character(), silver_estimate_column = character(), acs_variable = character(), stringsAsFactors = FALSE))
  }

  lines <- readLines(script_path, warn = FALSE)
  script_text <- paste(lines, collapse = "\n")
  out <- list()
  i <- 1L

  while (i <= length(lines)) {
    ln <- lines[[i]]
    m <- regexec("^\\s*([A-Za-z][A-Za-z0-9_]*)\\s*<-\\s*c\\s*\\(", ln)
    mm <- regmatches(ln, m)[[1]]
    if (length(mm) < 2) {
      i <- i + 1L
      next
    }

    var_set <- mm[2]
    in_use <- grepl(paste0("variables\\s*=\\s*", var_set, "\\b"), script_text)
    if (!in_use) {
      i <- i + 1L
      next
    }

    blk <- extract_block(lines, i)
    pairs <- gregexpr("([A-Za-z0-9_\\.]+)\\s*=\\s*\"([A-Za-z0-9_]+)\"", blk$text, perl = TRUE)
    hits <- regmatches(blk$text, pairs)[[1]]

    if (length(hits) > 0) {
      metric_key_raw <- sub("\\s*=.*$", "", hits)
      metric_key_raw <- trimws(metric_key_raw)
      acs_var <- sub("^.*=\\s*\"", "", hits)
      acs_var <- sub("\"$", "", acs_var)
      metric_key <- sub("\\.$", "", metric_key_raw)

      out[[length(out) + 1L]] <- data.frame(
        metric_key = metric_key,
        silver_estimate_column = paste0(metric_key, "E"),
        acs_variable = acs_var,
        stringsAsFactors = FALSE
      )
    }

    i <- blk$end_idx + 1L
  }

  if (length(out) == 0) {
    return(data.frame(metric_key = character(), silver_estimate_column = character(), acs_variable = character(), stringsAsFactors = FALSE))
  }
  unique(do.call(rbind, out))
}

resolve_db_path <- function() {
  # Preferred path via project utils/env
  candidate <- NA_character_
  try({
    source("scripts/utils.R")
    if (file.exists(".Renviron")) readRenviron(".Renviron")
    data_dir <- get_env_path("DATA")
    p <- file.path(data_dir, "duckdb", "metro_deep_dive.duckdb")
    if (file.exists(p)) candidate <- p
  }, silent = TRUE)

  if (!is.na(candidate) && nzchar(candidate)) return(candidate)

  local_candidate <- file.path("data", "duckdb", "metro_deep_dive.duckdb")
  if (file.exists(local_candidate)) return(local_candidate)

  NA_character_
}

load_acs_lookup_from_db <- function() {
  if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("duckdb", quietly = TRUE)) {
    return(data.frame())
  }

  db_path <- resolve_db_path()
  if (is.na(db_path) || !file.exists(db_path)) return(data.frame())

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  exists <- DBI::dbGetQuery(con, "
    SELECT COUNT(*) AS n
    FROM information_schema.tables
    WHERE table_schema = 'silver' AND table_name = 'acs_variable_dictionary'
  ")
  if (exists$n[[1]] == 0) return(data.frame())

  DBI::dbGetQuery(con, "
    SELECT metric_key, silver_estimate_column, acs_variable,
           acs_label_clean, acs_concept_2024, lookup_year, lookup_dataset, label_match_status
    FROM silver.acs_variable_dictionary
  ")
}

pretty_acs_label <- function(x) {
  x <- gsub("!!", ", ", x, fixed = TRUE)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

build_acs_definition <- function(concept, acs_variable, label, year = 2024L) {
  concept <- trimws(as.character(concept))
  label <- pretty_acs_label(label)
  sprintf("ACS %s %s [%s]: %s (estimate).", as.character(year), concept, acs_variable, label)
}

metric_phrase_from_name <- function(nm) {
  s <- nm
  s <- gsub("^pct_", "", s)
  s <- gsub("_", " ", s)
  s <- gsub("\\b([0-9]+)p\\b", "\\1+", s, perl = TRUE)
  s <- gsub("\\b([0-9]+)_([0-9]+)\\b", "\\1 to \\2", s, perl = TRUE)
  s <- gsub("\\s+", " ", s, perl = TRUE)
  trimws(s)
}

extract_assignments_from_silver_script <- function(script_path) {
  if (!file.exists(script_path)) return(data.frame(lhs = character(), rhs = character(), stringsAsFactors = FALSE))

  lines <- readLines(script_path, warn = FALSE)
  # strip inline comments
  lines <- sub("#.*$", "", lines)
  txt <- paste(lines, collapse = "\n")
  txt <- gsub("\n", " ", txt)

  # coarse parse of assignments used in mutate/select pipelines
  m <- gregexpr("([A-Za-z][A-Za-z0-9_]*)\\s*=\\s*([^,\\)](?:[^,]|\\([^\\)]*\\))+)", txt, perl = TRUE)
  hits <- regmatches(txt, m)[[1]]
  if (length(hits) == 0) return(data.frame(lhs = character(), rhs = character(), stringsAsFactors = FALSE))

  lhs <- trimws(sub("=.*$", "", hits))
  rhs <- trimws(sub("^[^=]*=", "", hits))

  df <- data.frame(lhs = lhs, rhs = rhs, stringsAsFactors = FALSE)
  # Keep unique latest assignment for each lhs
  df <- df[!duplicated(df$lhs, fromLast = TRUE), , drop = FALSE]
  df
}

classify_formula <- function(rhs) {
  r <- gsub("\\s+", "", rhs)
  if (grepl("/", r)) return("ratio")
  if (grepl("\\+", r)) return("sum")
  if (grepl("^[A-Za-z][A-Za-z0-9_\\.]*[EeMm]?$", r)) return("direct")
  "other"
}

semantic_from_formula <- function(metric_name, rhs, base_semantic) {
  cls <- classify_formula(rhs)

  if (startsWith(metric_name, "pct_")) {
    phrase <- metric_phrase_from_name(metric_name)
    return(list(definition = sprintf("Share of %s (0 to 1).", phrase), confidence = "high", formula_class = cls))
  }

  if (cls == "direct") {
    key <- normalize_metric_key(rhs)
    if (!is.null(base_semantic[[key]]) && nzchar(base_semantic[[key]])) {
      return(list(definition = base_semantic[[key]], confidence = "high", formula_class = cls))
    }
  }

  if (cls == "ratio") {
    tokens <- unique(unlist(regmatches(rhs, gregexpr("[A-Za-z][A-Za-z0-9_]*", rhs, perl = TRUE))))
    denom <- if (length(tokens) > 0) tokens[length(tokens)] else "denominator"
    num <- if (length(tokens) > 1) paste(tokens[1:(length(tokens) - 1)], collapse = " + ") else "numerator"
    return(list(definition = sprintf("Ratio of %s to %s.", metric_phrase_from_name(num), metric_phrase_from_name(denom)), confidence = "medium", formula_class = cls))
  }

  if (cls == "sum") {
    return(list(definition = sprintf("Population count for %s.", metric_phrase_from_name(metric_name)), confidence = "medium", formula_class = cls))
  }

  list(definition = sprintf("Business metric for %s.", metric_phrase_from_name(metric_name)), confidence = "low", formula_class = cls)
}

sync_md_columns_from_yaml <- function(yml_path) {
  md_path <- sub("\\.yml$", ".md", yml_path)
  if (!file.exists(md_path)) return(FALSE)

  obj <- yaml::read_yaml(yml_path)
  if (is.null(obj$columns) || length(obj$columns) == 0) return(FALSE)

  is_missing <- function(x) {
    if (is.null(x) || length(x) == 0 || all(is.na(x))) return(TRUE)
    if (is.character(x)) {
      xv <- trimws(tolower(x))
      if (xv %in% c("na", "nan", "null", "~", "")) return(TRUE)
    }
    FALSE
  }

  fmt_num <- function(x) {
    if (is_missing(x)) return("")
    xv <- suppressWarnings(as.numeric(x))
    if (!is.na(xv) && abs(xv - round(xv)) < .Machine$double.eps^0.5) return(format(xv, scientific = FALSE, trim = TRUE))
    as.character(x)
  }
  fmt_null <- function(x) if (is_missing(x)) "" else sprintf("%.4f", as.numeric(x))
  fmt_range <- function(col) {
    minv <- col$min_value; maxv <- col$max_value; minl <- col$min_length; maxl <- col$max_length
    has_minv <- !is_missing(minv); has_maxv <- !is_missing(maxv); has_minl <- !is_missing(minl); has_maxl <- !is_missing(maxl)
    if (has_minv && has_maxv) return(sprintf("min %s, max %s", fmt_num(minv), fmt_num(maxv)))
    if (has_minl && has_maxl) return(sprintf("len %s-%s", fmt_num(minl), fmt_num(maxl)))
    ""
  }
  fmt_top <- function(col) {
    tv <- col$top_values
    if (is.null(tv) || length(tv) == 0) return("")
    vals <- vapply(tv, function(x) {
      v <- if (!is.null(x$value) && !is_missing(x$value)) as.character(x$value) else "NULL"
      c <- if (!is.null(x$count) && !is_missing(x$count)) as.character(x$count) else ""
      if (nzchar(c)) sprintf("%s (%s)", v, c) else v
    }, character(1))
    paste(vals, collapse = "; ")
  }

  rows <- c("| Column | DuckDB type | Null % | Distinct | Range / Length | Top values (count) | Definition |",
            "|---|---|---:|---:|---|---|---|")
  for (col in obj$columns) {
    esc <- function(s) gsub("\\|", "\\\\|", s)
    rows <- c(rows, sprintf("| `%s` | `%s` | %s | %s | %s | %s | %s |",
      esc(col$name), esc(col$type), fmt_null(col$null_pct), fmt_num(col$distinct_count),
      esc(fmt_range(col)), esc(fmt_top(col)), esc(ifelse(is.null(col$definition), "", as.character(col$definition)))
    ))
  }

  md_lines <- readLines(md_path, warn = FALSE)
  i_cols <- grep("^## Columns\\s*$", md_lines)
  if (length(i_cols) == 0) return(FALSE)
  i_cols <- i_cols[1]
  next_h <- grep("^## ", md_lines)
  next_h <- next_h[next_h > i_cols]
  i_end <- if (length(next_h) > 0) next_h[1] - 1 else length(md_lines)

  prefix <- if (i_cols > 1) md_lines[1:(i_cols - 1)] else character(0)
  suffix <- if (i_end < length(md_lines)) md_lines[(i_end + 1):length(md_lines)] else character(0)
  new_lines <- c(prefix, "## Columns", "", rows, suffix)

  if (!identical(md_lines, new_lines)) {
    writeLines(new_lines, md_path, useBytes = TRUE)
    return(TRUE)
  }
  FALSE
}
