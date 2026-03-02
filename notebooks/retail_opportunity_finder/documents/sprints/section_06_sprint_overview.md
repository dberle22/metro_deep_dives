# Sprint E Overview - Section 06 Conclusion + Appendix

## Objective
Build Section 06 as a standalone, validated module that provides:
- final recommendations and next actions
- appendix definitions, assumptions, caveats, and QA summary

Shared workflow reference: `notebooks/retail_opportunity_finder/sections/_shared/AGENT_INSTRUCTIONS.md`

## Scope
1. Implement Section 06 build artifacts.
2. Implement Section 06 visuals/tables for notebook consumption.
3. Implement Section 06 checks and validation report.
4. Keep Section 06 integration-ready for Sprint F.

## Inputs
- Section 03 validation + scoring outputs
- Section 04 zone summary + validation outputs
- Section 05 shortlist + validation outputs

## Execution Plan

### E1 - Build (`section_06_build.R`)
- [x] Load required upstream artifacts from Sections 03-05.
- [x] Create conclusion payload:
  - [x] top zone/system highlights
  - [x] shortlist summary statistics
  - [x] recommended next actions
- [x] Create appendix payload:
  - [x] KPI dictionary snapshot
  - [x] assumptions/caveats list
  - [x] QA summary rollup from Section validation reports
- [x] Persist `outputs/section_06_conclusion_payload.rds`
- [x] Persist `outputs/section_06_appendix_payload.rds`

### E2 - Visuals (`section_06_visuals.R`)
- [x] Build conclusion summary table object.
- [x] Build appendix QA summary table object.
- [x] Build assumptions/caveats table object.
- [x] Persist `outputs/section_06_visual_objects.rds`

### E3 - Checks (`section_06_checks.R`)
- [x] Validate Section 06 payload schemas.
- [x] Validate required references to Section 03-05 outputs.
- [x] Validate no missing required narrative fields.
- [x] Persist `outputs/section_06_validation_report.rds`
- [x] Hard fail on missing required appendix/QA fields.

## Acceptance Criteria
- [x] Section 06 scripts (`build`, `visuals`, `checks`) run cleanly.
- [x] `section_06_validation_report.rds` has `pass=TRUE`.
- [x] Section 06 artifacts are integration-ready for Sprint F.

## Proposed Artifacts
- `outputs/section_06_conclusion_payload.rds`
- `outputs/section_06_appendix_payload.rds`
- `outputs/section_06_visual_objects.rds`
- `outputs/section_06_validation_report.rds`
