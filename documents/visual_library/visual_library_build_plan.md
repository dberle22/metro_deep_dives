# Visual Library Build Plan

## Goal
Build a reusable visual library that standardizes chart design, data contracts, and rendering logic across metro deep dive analyses.

## Planned Steps

### Phase 1: Foundation
1. Create a canonical chart spec template based on the Line Graph section in `sample_library.md`.
2. Create a visual registry file (`config/visual_registry.yml`) to track each chart type and implementation status.
3. Define initial data contract schemas (required fields, types, grain, assumptions) for first-priority chart types.
4. Create a visual standards decision space (`documents/visual_library/visual_standards.md`) to track fonts, palettes, annotation rules, and branding conventions as we implement chart types.
5. Create shared visual standards helpers in `R/visual/standards.R` for themes, labels, formatting, and source/vintage footers.
6. Create a benchmark reference file (`documents/visual_library/benchmark_defaults.md`) with default benchmark sets by granularity.

### Phase 2: Reusable Pipeline Layers
1. Build data contract validators in `R/visual/data_contracts.R`.
2. Build prep functions by chart type inside chart folders (for example `documents/visual_library/charts/line/prep_line.R`) to transform data into plotting-ready structures.
3. Build render functions by chart type inside chart folders (for example `documents/visual_library/charts/line/render_line.R`) with consistent title/subtitle/unit/legend behavior.
4. Refactor existing script-level visuals to thin wrappers that call prep + render + export.
5. For each chart type, maintain a `sample_output/` folder that includes:
   - a DuckDB SQL builder file for sample data,
   - a business-question testing file, and
   - generated PNG test outputs.

### Phase 3: Chart Family Rollout
1. Implement `Daily Drivers` first:
   - Bar Charts
   - Line Charts
   - Scatter Plots
   - Choropleth Maps
   - Hexbin / 2D Binned Scatter
2. Implement `Story Upgraders` second:
   - Highlight + Context Map
   - Correlation Heatmap
   - Slopegraph
   - Heatmap Table
   - Strength Strip / Scorecard Bars
3. Implement `Deep Dive Specialists` third:
   - Age Pyramid
   - Bump Chart
   - Waterfall
   - Bivariate Choropleth
   - Proportional Symbol Map
4. Add `Nice-to-Haves` only when tied to a specific analysis question.

### Phase 4: QA and Governance
1. Add tests for data contract compliance (required columns, type checks, period coverage, transform correctness).
2. Add visual QA checklists per chart spec (period ranges, units, transforms, missing-period behavior, legend readability).
3. Build a registry-driven render script (`scripts/visual/run_visual_registry.R`) for repeatable chart generation.
4. Produce run manifests for reproducibility (inputs, parameters, outputs, timestamp).

### Phase 5: Sample Data from DuckDB
1. Create a repeatable script to generate chart-ready sample datasets from DuckDB (`scripts/visual/build_sample_data_from_duckdb.R`).
2. Store sample data outputs under a dedicated folder for tests and demos (for example `data/visual_samples/`).
3. Ensure each chart type has at least one representative sample dataset tied to its contract.
4. Use sample datasets as required fixtures for visual smoke tests and acceptance checks.

## Planned Agents

### Skill Storage, Editing, and Usage
- Codex skills are stored locally under `/Users/danberle/.codex/skills/`.
- Each skill should be a folder with at least `SKILL.md` and may also include `agents/openai.yaml`, `scripts/`, `references/`, and `assets/`.
- To edit a skill, update its files directly on disk (usually `SKILL.md` first, plus any bundled resources).
- To use a skill, reference it by name in your prompt or ask for a task that matches the skill description so Codex triggers it.
- Skill updates are picked up from the local files in future runs.

1. `visual-spec-author`
- Purpose: Draft and maintain per-chart spec docs using the canonical template.
- Inputs: Chart type, business question, required metrics/geographies.
- Outputs: Completed chart spec markdown with QA checklist and question bank.

2. `visual-contract-checker`
- Purpose: Validate input data against the chart’s required contract before rendering.
- Inputs: Dataset + chart contract id.
- Outputs: Pass/fail report with blocking issues and suggested fixes.

3. `visual-function-scaffolder`
- Purpose: Generate reusable `prep_*` and `render_*` R function stubs with standard signatures.
- Inputs: Chart spec + registry entry.
- Outputs: New/updated function files and test stubs.

4. `visual-registry-runner`
- Purpose: Execute chart builds from `visual_registry.yml` for one metro or batch runs.
- Inputs: Registry, metro parameters, output config.
- Outputs: Rendered artifacts + run manifest.

5. `visual-qa-reviewer`
- Purpose: Apply visual QA rubric and flag readability/interpretation risks.
- Inputs: Rendered chart + spec.
- Outputs: QA result checklist and issue list.

## Decisions Needed From You

Use this section as a running decision log. For each decision point, record:
- `Question`
- `Answer`
- `Status` (`Open` or `Decided`)
- `Date`

### Decision 1: Priority order within `Daily Drivers`
- Question: Which two chart types should be implemented first?
- Answer: `Line Charts` first, then `Scatter Plots`.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 2: Output targets
- Question: PNG only, or PNG + SVG + HTML/Quarto-ready embeds?
- Answer: Start with `PNG` only. Reopen later if requirements change.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 3: Visual standards
- Question: Font family, palette rules, annotation style, branding constraints.
- Answer: Create and maintain a dedicated visual standards space; fill standards decisions incrementally as each chart type is implemented.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 4: Benchmark defaults
- Question: Default benchmark definitions by geo level (CBSA/state/region/national).
- Answer: Defaults depend on granularity. For Metro Areas, include `Division`, `National`, and `All Other Metro Areas`. Maintain these defaults in a benchmark reference file.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 5: Acceptance criteria
- Question: Minimum “done” criteria per chart type (technical + presentation quality).
- Answer: Minimum requirement is: (1) a chart contract `.md` filled like `sample_library.md`, (2) a `.R` file containing reusable code/function, and (3) a test output based on sample data created for that chart.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 6: Agent implementation scope
- Question: Do you want all five agents created now as Codex skills, or stage them over time?
- Answer: Create all five now as Codex skills.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 7: Contract file location
- Question: Where should visual contract CSV files live?
- Answer: Keep visual contract files in `documents/visual_library/contracts/` to consolidate visual library work.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 8: Per-chart folder structure
- Question: How should each chart implementation be organized?
- Answer: Build each chart type in its own folder under `documents/visual_library/charts/<chart_type>/` with `prep_<chart_type>.R`, `render_<chart_type>.R`, and `<chart_type>_spec.md`.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 9: Sample output and testing assets
- Question: What should be included for chart testing and sample outputs?
- Answer: Include a `sample_output/` folder per chart with a `.sql` file that builds the sample dataframe and a business-question testing file to validate visual build/output generation.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 11: Business question source priority
- Question: Should business questions default from `sample_library.md` or chart-specific specs?
- Answer: Default to chart-specific spec first; use `sample_library.md` as fallback.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 12: Folder creation trigger
- Question: When a chart-type task starts, should the Agent create the chart folder organization automatically?
- Answer: Yes. The Agent should create the chart folder structure in `documents/visual_library/charts/<chart_type>/` at the start of execution.
- Status: `Decided`
- Date: `2026-03-02`

### Decision 13: Step execution order
- Question: Should the Agent execute workflow steps strictly one at a time?
- Answer: Yes. Complete each step and confirm before moving to the next.
- Status: `Decided`
- Date: `2026-03-02`

## Suggested Immediate Next Step
Finalize decisions above, then scaffold Phase 1 files (`chart_spec_template.md`, `visual_registry.yml`, line-chart contract + function stubs) in one pass.
