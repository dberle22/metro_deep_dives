# Visual Library Agent Workflow

## Purpose
Define the standard workflow between the `User` (prompter) and the `Agent` (Codex) for building a new chart type in the visual library.

## Roles
- `User`: Chooses chart types, reviews decisions, confirms relevance, approves standards.
- `Agent`: Drafts specs, finds reusable samples, builds data/testing assets, validates outputs, and proposes reusable functions.

## Workflow

## Execution Rule
- Run workflow steps strictly one at a time.
- Complete the current step, share output with the User, and get confirmation before moving to the next step.
- Do not skip ahead unless the User explicitly asks to combine or bypass steps.
- Record chart-build decisions in the chart folder (for example `documents/visual_library/charts/<chart_type>/<chart_type>_decisions.md`) instead of the global build plan.

### 1. Pick a chart type
- Owner: `User`
- Action: User specifies the chart type and prompts the Agent to start.
- Output: Confirmed target chart type and scope.

### 1A. Create chart folder organization
- Owner: `Agent`
- Action:
  - Immediately create the standard chart folder structure for the selected chart type under `documents/visual_library/charts/<chart_type>/`.
  - Include `sample_output/` subfolder and expected starter files when missing.
- Output: Chart workspace exists before spec, SQL, and testing work begins.

### 2. Draft details and specs
- Owner: `Agent` with `User` confirmation
- Action:
  - Use [sample_library.md](/Users/danberle/Documents/projects/metro_deep_dive/documents/visual_library/sample_library.md) as the template style.
  - Ask the User to paste existing chart details/specs if available.
  - If none exist, draft initial chart spec and review with User.
- Output: Working chart spec (`<chart_type>_spec.md`) approved or marked for revision.

### 3. Find relevant prior samples
- Owner: `Agent`, then `User` decision
- Action:
  - Search the repo for similar visuals, scripts, and notebooks.
  - Summarize what was found and recommended reusable patterns.
  - User confirms whether each sample is relevant.
- Output: Confirmed list of relevant prior implementations and reuse notes.

### 4. Select business questions and build SQL
- Owner: `Agent` drafts, `User` reviews
- Action:
  - Propose business questions from the chart-specific spec first, and use `sample_library.md` as fallback guidance if needed.
  - Build DuckDB SQL to create chart-ready sample dataframe(s), using data dictionary/schema context.
  - Ask User to approve/adjust questions and SQL assumptions.
- Output: Approved business questions and sample SQL in `sample_output/`.

### 5. Validate the dataframe for visualization
- Owner: `Agent`
- Action:
  - Validate required/optional contract fields.
  - Verify grain, types, period coverage, missing values, and transform prerequisites.
- Output: Validation result (pass/fail) and any required fixes.

### 6. Produce chart output
- Owner: `Agent`
- Action:
  - Run prep and render scripts.
  - Save chart PNG outputs in the chart’s `sample_output/` folder.
- Output: Test output images for User review.

### 7. Propose reusable components
- Owner: `Agent`, then `User` decision
- Action:
  - Identify what should be promoted to shared library components (helpers, standards, contract checks, utilities).
  - Present recommendations and tradeoffs.
- Output: User-approved reusable component changes.

### 8. Final review and documentation check
- Owner: `Agent`
- Action:
  - Verify scripts run cleanly end-to-end.
  - Confirm sample files and testing notes are documented.
  - Confirm chart folder structure is complete.
- Output: QA summary and readiness status.

### 9. Propose reusable function
- Owner: `Agent`, then `User` approval
- Action:
  - Propose final reusable function(s) and signatures for the chart type.
  - Explain how function plugs into the visual registry workflow.
- Output: Final function proposal (and implementation if approved).

## Required Artifacts Per Chart Type
- `<chart_type>_spec.md`
- `prep_<chart_type>.R`
- `render_<chart_type>.R`
- `sample_output/build_<chart_type>_sample.sql`
- `sample_output/test_<chart_type>_business_questions.md`
- `sample_output/test_<chart_type>_render.R`
- PNG output(s) in `sample_output/`

## Agent Review Checklist
- Chart type and scope confirmed
- Spec reviewed with User
- Prior sample relevance confirmed
- Business questions approved
- SQL/dataframe validated
- PNG outputs generated
- Reusable components proposed
- Scripts and docs pass final review
- Reusable function proposed
