# Sprint F Overview - Notebook Integration + Render Hardening

## Objective
Integrate validated outputs from Sections 03-06 into `retail_opportunity_finder_dash_v1.qmd` and deliver a stable, end-to-end render.

Shared workflow reference: `notebooks/retail_opportunity_finder/sections/_shared/AGENT_INSTRUCTIONS.md`

## Scope
1. Wire section artifacts into `.qmd` without re-implementing heavy transforms.
2. Validate narrative coherence and formatting consistency.
3. Achieve full render completion without manual intervention.

## Inputs
- Section 03 outputs + `section_03_validation_report.rds`
- Section 04 outputs + `section_04_validation_report.rds`
- Section 05 outputs + `section_05_validation_report.rds`
- Section 06 outputs + `section_06_validation_report.rds`

## Execution Plan

### F1 - Preflight and contracts
- [ ] Confirm required artifacts exist for Sections 03-06.
- [ ] Confirm each section validation report has `pass=TRUE`.
- [ ] Lock object names used by `.qmd`.

### F2 - QMD integration passes
- [ ] Integrate Section 03 visuals/tables and narrative references.
- [ ] Integrate Section 04 visuals/tables and narrative references.
- [ ] Integrate Section 05 visuals/tables:
  - [ ] cluster-default narrative view
  - [ ] contiguity comparison view
- [ ] Integrate Section 06 conclusion + appendix objects.

### F3 - Render hardening
- [ ] Run full notebook render.
- [ ] Resolve runtime and dependency errors.
- [ ] Resolve figure/table display issues.
- [ ] Re-render until stable and reproducible.

### F4 - Final quality pass
- [ ] Standardize labels, units, and captions.
- [ ] Ensure source notes/caveats are visible where needed.
- [ ] Save integration validation summary artifact/log.

## Acceptance Criteria
- [ ] Full `.qmd` render completes end-to-end with no manual intervention.
- [ ] All required section outputs are present in final report.
- [ ] Section 05 shows cluster as default with contiguity comparison included.
- [ ] Final notebook includes conclusion + appendix with assumptions and QA caveats.

## Proposed Integration Outputs
- Updated `retail_opportunity_finder_dash_v1.qmd`
- Render output document(s)
- Integration validation summary log (path to be finalized during sprint)
