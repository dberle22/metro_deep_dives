# Sprint F Integration Workspace

This folder is the dedicated workspace for **Sprint F** (notebook integration + render hardening).

## Purpose
- integrate validated section artifacts into the final notebook
- run integration-specific checks and tests
- track rendering issues and fixes
- host visual overrides/customizations used only at integration layer
- keep non-code planning/sprint docs centralized in `../documents/`

## Principles
- Section modules (`sections/03`-`sections/06`) remain source-of-truth for core computation.
- Integration layer focuses on composition, presentation, and reproducibility.
- Any customization that changes core logic should be pushed back into section modules.
- Notebook runtime policy: integration and `.qmd` render must read prebuilt artifacts (`*.rds` and static files) only; do not execute section build/visual/check scripts during notebook render.

## Folder structure
- `tests/`: integration checks (artifact existence, render smoke tests, regression checks)
- `scripts/`: helper scripts for integration tasks
- `visual_overrides/`: optional custom visuals for final notebook polish
- `outputs/`: integration logs, snapshots, validation outputs
- `qmd/`: optional staging notebook(s) for integration work

## Sprint F run order
1. Confirm all section validation reports pass (`sections/03`-`sections/06`).
2. Wire section artifacts into notebook staging file.
3. Run full render and capture issues.
4. Apply fixes and re-render until stable.
5. Produce integration validation summary in `outputs/`.
