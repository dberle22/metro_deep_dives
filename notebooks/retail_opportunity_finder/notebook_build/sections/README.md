# Notebook Build Sections

Future section modules in this folder should be thin consumers of prepared data products.

## Design Intent
- Sections 01, 02, and 06 may remain thin assembly layers, but they still run from `notebook_build/`
- no first-principles tract scoring
- no first-principles zone construction
- no parcel canonicalization in report scripts
- no DuckDB publication or overwrite from notebook-build
- compatibility artifacts may still be written under `sections/*/outputs/` while visuals and integration remain on the legacy artifact contracts
