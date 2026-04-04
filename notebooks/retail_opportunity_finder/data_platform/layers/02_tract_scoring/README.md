# Layer 02 - Tract Scoring

This layer moves tract eligibility scoring upstream into a reusable workflow.

## First Slice
- Shared scoring functions extracted from Section 03.
- DuckDB publication for tract scores and cluster seed tracts.
- Section 03 remains a compatibility consumer and artifact exporter.

## Current Products
- `scoring.tract_scores`
- `scoring.cluster_seed_tracts`

## Still Pending
- Model registry externalization
- scoring version governance
- explicit QA run tables
