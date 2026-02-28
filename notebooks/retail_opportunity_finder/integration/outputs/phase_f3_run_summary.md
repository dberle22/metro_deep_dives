# Phase F3 Run Summary

- phase: `F3 - Narrative + visual integration passes`
- notebook: `notebooks/retail_opportunity_finder/integration/qmd/retail_opportunity_finder_mvp.qmd`
- render_output: `notebooks/retail_opportunity_finder/integration/qmd/retail_opportunity_finder_mvp.html`
- render_status: `PASS`
- runtime_mode: `artifact-only (readRDS + static assets)`

## Notes
- Section 1-6 narrative and visual blocks were integrated.
- Cluster-first narrative is the primary path in Sections 4 and 5.
- Contiguity comparisons are retained as secondary views.
- Render pathing was hardened by resolving project root dynamically in the loader chunk.

## Known Warnings (from section validation artifacts)
- Section 04: zone count outside target band (contiguity zones = 16).
- Section 05:
  - parcel->zone assignment rate below warning threshold for both systems (~0.257)
  - invalid shortlist geometries present (207 in each system)
