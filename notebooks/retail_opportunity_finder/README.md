# Retail Opportunity Finder

Retail Opportunity Finder (ROF) is organized into three layers:

- `sections/`: section-by-section build, checks, and visuals (`01`-`06`)
- `integration/qmd/`: integrated notebook authoring and render source (`retail_opportunity_finder_mvp.qmd`)
- `docs/rof-mvp/` (repo root): GitHub Pages publish payload

## Architecture

Pipeline order:

`01_setup -> 02_market_overview -> 03_eligibility_scoring -> 04_zones -> 05_parcels -> 06_conclusion_appendix`

Per section convention:

- `section_XX_build.R`: transformations and artifact construction
- `section_XX_checks.R`: validation and QA rules
- `section_XX_visuals.R`: section-level visualization objects
- `outputs/`: produced artifacts for downstream sections/integration

## Current operating mode

- Zone system: **cluster-first** is the active path for MVP
- Contiguity artifacts are retained for historical comparison but are not the primary narrative path

## Directory map

- `documents/`
  - `plans/`: notebook flow and build plans
  - `sprints/`: sprint overviews and checklists
  - `improvements/`: MVP and V2 improvement logs
- `legacy/`: older dashboard assets retained for reference only
- `sections/_shared/`: shared bootstrap/config/helper functions and project-level contracts

## Key entry points

- Integrated notebook source: `notebooks/retail_opportunity_finder/integration/qmd/retail_opportunity_finder_mvp.qmd`
- Planning/sprint/improvement docs: `notebooks/retail_opportunity_finder/documents/`
- Shared utilities: `notebooks/retail_opportunity_finder/sections/_shared/`

## Source-of-truth rules

- Business/report authoring source: `integration/qmd/retail_opportunity_finder_mvp.qmd`
- Public web publish source: `docs/rof-mvp/` (from publish script)
- Section computation source: `sections/*/section_XX_build.R` and `section_XX_checks.R`
- Do not treat generated section `outputs/` artifacts as hand-edited source files

## Publish workflow

1. Render and sync the public site payload:
   - `./scripts/publish_rof_mvp.sh`
2. Commit updates under `docs/rof-mvp`
3. GitHub Pages serves from `main` + `/docs`

Public URL pattern:

- `https://<org-or-user>.github.io/<repo>/rof-mvp/`

## Pre-V2 repository recommendations

- Keep all strategy/planning docs in `documents/` only
- Keep legacy notebook/dashboard assets in `legacy/` only
- Keep Pages payload in `docs/rof-mvp/` only
- Keep section logic changes inside section modules, not integration-only patches
- Periodically remove accidental OS/editor artifacts (for example `.DS_Store`)
