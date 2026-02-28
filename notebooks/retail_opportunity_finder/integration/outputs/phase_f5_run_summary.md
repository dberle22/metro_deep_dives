# Phase F5 Run Summary

- phase: `F5 - Quality and caveat pass`
- notebook: `notebooks/retail_opportunity_finder/integration/qmd/retail_opportunity_finder_mvp.qmd`
- render_output: `notebooks/retail_opportunity_finder/integration/qmd/retail_opportunity_finder_mvp.html`
- render_status: `PASS`
- runtime_mode: `artifact-only (readRDS + static assets)`

## Completed in F5
- Added explicit unit/interpretation guidance in Section 2 narrative.
- Added figure captions/source notes to major diagnostic and map visuals across Sections 2-5.
- Added explicit scoring-weight sentence in Section 3.
- Added Section 04 caveat table fed directly from `section_04_validation_report.rds` warnings.
- Added Section 05 caveat table fed directly from `section_05_validation_report.rds` warnings.
- Added Section 05 assignment-rate metrics to narrative using validation coverage metrics.
- Added explicit appendix framing note in Section 6 so caveats/assumptions are discoverable.

## Carry-forward caveats shown in notebook
- Section 04 contiguity zone count warning (`16` zones, outside target band).
- Section 05 assignment-rate warnings (~25.7% for both systems).
- Section 05 invalid shortlist geometries warning (`207` each system).
