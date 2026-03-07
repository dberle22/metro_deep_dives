# Visual Standards

## Purpose
Central source of truth for visual standards, options, and usage guidance across the visual library.

## Standards Files (Code)
- Shared style and formatting: `R/visual/standards.R`
- Scatter rendering defaults/options: `R/visual/render_scatter.R`
- Scatter prep rules: `R/visual/prep_scatter.R`
- Data contract validations: `R/visual/data_contracts.R`
- Query helpers for SQL-driven visual tests: `R/visual/scatter_query_helpers.R`

## How To Use Standards
1. Load `R/visual/standards.R` in chart test/render scripts.
2. Use shared prep/render functions from `R/visual/`.
3. Override defaults only when chart-specific requirements justify it.
4. Record chart-specific visual exceptions in that chart folder's decision log.

## Current Defaults
- Export format: `PNG`
- Base theme: `theme_minimal()` wrapped by `visual_theme()`
- Background: white for panels and exports
- Number formatting: use `scales` helpers
- Caption: use `build_chart_notes()` for source/vintage + notes/footer

## Standard Options and Guidance

### 1) Call Out Boxes
Status: Standardized (initial)

Use cases:
- Scatter Plots
- Maps
- Box Plots

Inputs:
- `label_flag` (required for callouts): boolean flag for highlighted rows
- `geo_name` (default label text)
- optional `label_text` (future override field if needed)
- `highlight_mode`: `labels` for callout labels, `color` for colored subset

Modes:
- Single callout: set one row `label_flag = TRUE`
- Multiple callouts: set multiple rows `label_flag = TRUE`

Guidance:
- Keep callouts intentionally sparse for readability.
- Use callouts for meaningful outliers/targets, not all top values.

### 2) Color Palettes
Status: Standardized (initial)

Default:
- `viridis` is the primary palette.

Supported options (current scatter implementation):
- `viridis`
- `set2`
- manual base/highlight colors for subset mode

Guidance:
- Start with `viridis` for categorical grouping.
- Use manual highlight colors only when emphasizing a subset.

### 3) Trend Lines (Scatter)
Status: Standardized (initial)

Rule:
- Trend lines are standard for scatter plots.
- Must be toggleable off.
- Line style should be dashed.
- Opacity should be configurable.

Current controls in `render_scatter()`:
- `add_trend_line` (default `TRUE`)
- `trend_line_alpha`
- linetype/color defaults from `scatter_style_defaults`

### 4) Side Notes and Footers
Status: Standardized (initial)

Rule:
- Include source + vintage by default.
- Support additional side note and footer note text.

Current input pattern:
- `side_note`
- `footer_note`
- `build_chart_notes(source, vintage, side_note, footer_note)`

Guidance:
- Keep side notes concise (method caveats, scope notes).
- Keep footers for source and vintage metadata.

### 5) Legends
Status: Standardized (initial)

Rules:
- Remove NA legend categories where possible.
- Avoid scientific notation in legend values.

Current implementation:
- Discrete color scales use `na.translate = FALSE`.
- Size legend uses comma labels (`scales::label_comma()`).

Guidance:
- If NAs must be shown, rename to a cleaner category (for example `Unknown`).
- Keep legend labels human-readable and compact.

## Decision Log

### VS-001: Output format
- Question: What is the default export format?
- Answer: PNG only for now.
- Status: Decided
- Date: 2026-03-02

### VS-002: Fonts
- Question: What font family/families should be used across charts?
- Answer: TBD
- Status: Open
- Date: 2026-03-02

### VS-003: Color palette
- Question: What default palette(s) should be used by chart type?
- Answer: Default to `viridis`; allow alternatives (`set2`, manual highlights) when needed.
- Status: Decided
- Date: 2026-03-04

### VS-004: Annotation style
- Question: What annotation style should be standard (callouts, arrows, labels)?
- Answer: Standardize callout boxes via label overlays (`label_flag`) with support for single or multiple callouts.
- Status: Decided
- Date: 2026-03-04

### VS-005: Brand constraints
- Question: Are there required brand colors, logo usage, or layout constraints?
- Answer: TBD
- Status: Open
- Date: 2026-03-02

### VS-006: Scatter trend line standard
- Question: Should scatter trend lines be standard and configurable?
- Answer: Yes. Default on, dashed style, configurable opacity, and toggle off supported.
- Status: Decided
- Date: 2026-03-04

### VS-007: Notes and footer standard
- Question: How should side notes and footers be handled?
- Answer: Standardize via `build_chart_notes()` with source/vintage + optional side/footer notes.
- Status: Decided
- Date: 2026-03-04

### VS-008: Legend cleanup
- Question: How should legends handle NAs and numeric formatting?
- Answer: Drop NAs from legends by default and avoid scientific notation using readable numeric labels.
- Status: Decided
- Date: 2026-03-04
