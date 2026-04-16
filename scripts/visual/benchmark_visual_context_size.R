#!/usr/bin/env Rscript

files <- data.frame(
  scenario = c(
    "agent_file",
    "primary_skill",
    "supporting_skill",
    "supporting_skill",
    "supporting_skill",
    "supporting_skill",
    "visual_doc",
    "visual_doc"
  ),
  path = c(
    "visual_library/agent.md",
    "~/.codex/skills/visual-chart-builder/SKILL.md",
    "~/.codex/skills/visual-function-scaffolder/SKILL.md",
    "~/.codex/skills/visual-contract-checker/SKILL.md",
    "~/.codex/skills/visual-qa-reviewer/SKILL.md",
    "~/.codex/skills/visual-registry-runner/SKILL.md",
    "visual_library/sample_library.md",
    "visual_library/visual_style_guide_and_standards.md"
  ),
  stringsAsFactors = FALSE
)

normalize_path <- function(path) {
  path.expand(path)
}

count_file <- function(path) {
  full_path <- normalize_path(path)
  if (!file.exists(full_path)) {
    return(data.frame(
      bytes = NA_integer_,
      chars = NA_integer_,
      words = NA_integer_,
      approx_tokens_by_chars = NA_integer_,
      approx_tokens_by_words = NA_integer_
    ))
  }

  text <- paste(readLines(full_path, warn = FALSE), collapse = "\n")
  words <- unlist(strsplit(trimws(text), "\\s+"))
  word_count <- if (identical(words, "")) 0L else length(words)

  data.frame(
    bytes = file.info(full_path)$size,
    chars = nchar(text, type = "chars", allowNA = FALSE, keepNA = FALSE),
    words = word_count,
    approx_tokens_by_chars = ceiling(nchar(text, type = "chars") / 4),
    approx_tokens_by_words = ceiling(word_count * 1.33)
  )
}

counts <- do.call(rbind, lapply(files$path, count_file))
result <- cbind(files, counts)

print(result, row.names = FALSE)

summaries <- rbind(
  data.frame(
    bundle = "agent_file_only",
    subset(result, scenario == "agent_file")[c("bytes", "chars", "words", "approx_tokens_by_chars", "approx_tokens_by_words")]
  ),
  data.frame(
    bundle = "primary_skill_only",
    subset(result, scenario == "primary_skill")[c("bytes", "chars", "words", "approx_tokens_by_chars", "approx_tokens_by_words")]
  ),
  data.frame(
    bundle = "primary_plus_supporting_skills",
    as.data.frame(t(colSums(subset(result, scenario %in% c("primary_skill", "supporting_skill"))[
      c("bytes", "chars", "words", "approx_tokens_by_chars", "approx_tokens_by_words")
    ], na.rm = TRUE)))
  ),
  data.frame(
    bundle = "common_visual_docs",
    as.data.frame(t(colSums(subset(result, scenario == "visual_doc")[
      c("bytes", "chars", "words", "approx_tokens_by_chars", "approx_tokens_by_words")
    ], na.rm = TRUE)))
  )
)

cat("\nBundle summaries:\n")
print(summaries, row.names = FALSE)
