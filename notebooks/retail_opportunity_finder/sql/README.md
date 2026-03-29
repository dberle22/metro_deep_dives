# Retail Opportunity Finder SQL

This directory contains SQL query assets that feed Retail Opportunity Finder section builds and QA.

## Ownership

- `features/`: source-of-truth feature queries used by section build scripts. Primary owner: `ENG-Data`.
- `qa/`: SQL-only validation and inspection queries used during model/data QA. Primary owner: `ENG-QA`, with `ENG-Data` support.
- `staging/`: reserved for future intermediate transforms that should not live inside section scripts. Primary owner: `ENG-Data`.

## Execution intent

- `features/cbsa_features.sql`: CBSA-level feature spine for market overview and benchmark analysis.
- `features/tract_features.sql`: tract-level feature spine for eligibility scoring and downstream zoning/parcel work.
- `features/tract_universe.sql`: tract universe extraction for a target CBSA and tract geometry joins.
- `qa/tract_features_qa.sql`: manual QA checks for tract feature completeness, null rates, and eligibility counts.

## Usage rules

- Section scripts should resolve SQL files through the shared registry in `sections/_shared/config.R`.
- Do not add new root-level `.sql` files under `notebooks/retail_opportunity_finder/`.
- Keep feature queries deterministic and reusable across sections; section-specific filtering belongs in R unless it is part of the reusable SQL contract.
