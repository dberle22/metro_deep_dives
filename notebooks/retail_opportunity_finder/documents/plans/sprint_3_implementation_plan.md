# Retail Opportunity Finder V2 - Sprint 3 Finish Plan

## Purpose
Sprint 3 is no longer a greenfield implementation sprint. We already have the market profile layer, market-partitioned outputs for Sections 01-03, a working batch orchestrator for Sections 01-03, and the tract geometry adapter in place.

This finish plan focuses on closing the remaining Sprint 3 gaps so we can declare the Florida multi-market pilot complete and enter Sprint 4 from a stable base.

This plan intentionally does **not** include converting parcel ETL into a fully automated script. For Sprint 3, parcel work is limited to hardening the parcel input requirements, manual run contract, and downstream Section 05 assumptions.

## Current Status Snapshot

### Completed in practice
- Shared market profile registry exists and supports Florida plus near-term Southeast markets.
- Shared market-aware output helpers exist.
- Shared tract geometry adapter exists for `FL`, `GA`, `SC`, and `NC`.
- Sections 01-03 write to market-partitioned outputs.
- `scripts/run_markets.R` can run multiple markets through Section 03.
- A two-market pilot manifest already exists for Jacksonville and Gainesville.

### Not yet complete
- Full-pipeline multi-market execution still needs runtime validation after the downstream refactor.
- Section 05 parcel requirements are now documented more clearly, but still need pilot validation against the final market run.
- Sprint 3 signoff artifacts are not yet assembled as a clean release-gate package.

## Sprint 3 Finish Goal
Finish Sprint 3 when we can run at least two Florida markets through the full current ROF pipeline with isolated outputs, a current manifest, hardened parcel input requirements, and aligned docs.

## Locked Decisions

### 1. Parcel ETL remains manual in Sprint 3
- Do not build an automated county batch ETL script in this sprint.
- Preserve the current county-first manual workflow.
- Focus on making the manual process more explicit, repeatable, and contract-driven.

### 2. Sprint 3 closes on Florida full-pipeline support
- Sprint 3 should finish with full current-pipeline multi-market support for Florida.
- Non-Florida market execution remains future-facing infrastructure, not a Sprint 3 release requirement.

### 3. Market partitioning becomes the default path
- Sections 04-06 should move onto market-aware readers and writers.
- Legacy fallback reads may remain temporarily where they reduce transition risk, but new writes should be market-partitioned.

### 4. Documentation is part of the sprint closeout
- Sprint 3 is not done until the planning docs, output contracts, and parcel workflow docs all reflect the implemented system.

## Workstreams

## Workstream A - Extend Market-Partitioned Execution Through Sections 04-06

### Goal
Finish the market-aware refactor so downstream sections no longer depend on shared overwrite-prone output paths.

### Scope
- Refactor Section 04 reads and writes to use shared market-aware helpers consistently.
- Refactor Section 05 to consume market-partitioned Section 04 outputs.
- Refactor Section 06 to consume market-partitioned Section 03-05 outputs.
- Confirm the integration notebook can point at the intended market outputs without manual file juggling.

### Acceptance checks
- Running Market A does not overwrite Market B artifacts in Sections 04-06.
- Section 05 and Section 06 do not depend on fixed shared artifact paths for active inputs.
- A full current-pipeline Florida run can be reviewed market by market.

### Task checklist
- [x] `S3F-A1` Audit fixed output path usage in Sections 04-06 and integration code.
- [x] `S3F-A2` Refactor Section 04 readers/writers to market-aware helpers where missing.
- [x] `S3F-A3` Refactor Section 05 to read Section 04 artifacts via shared resolved paths.
- [x] `S3F-A4` Refactor Section 06 to read Section 03-05 artifacts via shared resolved paths.
- [ ] `S3F-A5` Validate that legacy fallback behavior is only transitional and not the primary path.

## Workstream B - Complete the Florida Multi-Market Pilot Runner

### Goal
Promote the current Section 01-03 batch runner into a Sprint 3 closeout runner for the full current pipeline.

### Scope
- Expand the section registry in `scripts/run_markets.R` beyond Section 03.
- Add QA/quality evaluation hooks for downstream sections where useful.
- Produce a fresh Florida pilot manifest from the full pipeline.
- Keep execution sequential for correctness and debuggability.

### Acceptance checks
- One command can run at least two Florida markets through the full implemented pipeline.
- The manifest records pass/fail, runtime, and output locations for the full run.
- Market failures remain isolated and easy to debug.

### Task checklist
- [x] `S3F-B1` Expand `run_markets.R` section registry to include Sections 04-06.
- [x] `S3F-B2` Add downstream artifact and validation summary capture for Sections 04-06.
- [ ] `S3F-B3` Run Jacksonville + Gainesville through the full pipeline with isolated outputs.
- [ ] `S3F-B4` Run Jacksonville + Orlando if Gainesville uncovers market-specific issues that need comparison coverage.
- [ ] `S3F-B5` Publish a fresh Sprint 3 manifest and concise pilot summary for signoff.

## Workstream C - Harden Parcel Requirements Without Automating ETL

### Goal
Keep the manual parcel workflow, but make its requirements explicit enough that Section 05 input preparation is stable and reviewable.

### Scope
- Define the minimum parcel input contract that Section 05 expects.
- Document required files, manifest fields, directory layout, QA artifacts, and rerun rules.
- Harden the boundary between manual county prep and Section 05 consumption.
- Clarify which fields are required now versus optional/future.

### Required outputs to harden
- Parcel standardized root expectations.
- County output directory naming rules.
- Required `parcel_ingest_manifest` fields.
- Required analysis artifact names and geometry CRS expectations.
- Minimum required parcel attributes for Section 05.
- QA requirements for unmatched joins, missing keys, and zero-county anomalies.

### Explicit non-goals
- No full automation framework.
- No multi-state production onboarding.
- No attempt to redesign the entire parcel platform in Sprint 3.

### Acceptance checks
- A teammate can follow the parcel docs and understand exactly what Section 05 needs.
- Section 05 input assumptions are documented, reviewable, and consistent with the current manual workflow.
- Manual county prep remains the operational path, but the downstream contract is clearer and less fragile.

### Task checklist
- [x] `S3F-C1` Write a minimum viable parcel input contract for Section 05 consumption.
- [x] `S3F-C2` Define the required schema and semantics for `parcel_ingest_manifest`.
- [x] `S3F-C3` Document required county output artifacts and directory conventions.
- [x] `S3F-C4` Document QA thresholds and required manual review steps for county parcel runs.
- [x] `S3F-C5` Align Section 05 assumptions and docs with the hardened manual parcel contract.

## Workstream D - Documentation Alignment and Sprint 3 Closeout Notes

### Goal
Make the docs tell the truth about current V2 progress and Sprint 3 scope.

### Documents to update
- `documents/plans/retail_opportunity_finder_v2_roadmap_plan.md`
- `documents/plans/sprint_3_implementation_plan.md`
- `sections/OUTPUT_CONTRACTS.md`
- `sections/05_parcels/parcel_standardization/README.md`
- `sections/05_parcels/final_pipeline_strategy_and_approach.md`
- `README.md` if any high-level operating notes are now stale

### Required doc outcomes
- Roadmap notes which Sprint 3 pieces are already implemented in practice and which remain.
- Sprint 3 plan reflects finish work, not kickoff assumptions.
- Output contracts describe market-partitioned artifact behavior for the active sections.
- Parcel docs clearly state the manual workflow and hardened downstream requirements.
- Signoff docs point to the correct pilot manifest and artifact locations.

### Acceptance checks
- A new contributor can read the docs and understand where V2 stands.
- The roadmap no longer understates Sprint 3 progress.
- Parcel docs no longer imply ambiguity about what Section 05 consumes.

### Task checklist
- [x] `S3F-D1` Update the roadmap with a Sprint 3 status note and closeout focus.
- [x] `S3F-D2` Replace the old Sprint 3 implementation kickoff narrative with this finish plan.
- [x] `S3F-D3` Update output contracts for market-partitioned reads and writes where applicable.
- [x] `S3F-D4` Update parcel standardization docs to emphasize hardened manual requirements.
- [ ] `S3F-D5` Add or refresh the Sprint 3 pilot summary document after the final run.

## Workstream E - Validation and Release-Gate Package

### Goal
Assemble the final evidence package needed to treat Sprint 3 as complete.

### Validation set
- Full-pipeline Jacksonville run
- Full-pipeline second Florida market run
- Section-by-section artifact existence checks
- Validation report pass/fail review
- Spot review of section visuals for both markets
- Parcel input readiness review against the hardened manual contract

### Release-gate outputs
- Final market batch manifest
- Short Sprint 3 closeout summary
- Known limitations list carried forward into Sprint 4
- List of deferred items explicitly outside Sprint 3 scope

### Task checklist
- [ ] `S3F-E1` Run full validation for the primary Florida pilot pair.
- [ ] `S3F-E2` Review output isolation, validation reports, and manifest completeness.
- [ ] `S3F-E3` Record known limitations and explicit Sprint 4 handoff items.
- [ ] `S3F-E4` Mark Sprint 3 ready for signoff in the planning docs.

## Sequencing Plan

### Phase 1 - Downstream refactor
1. Audit Sections 04-06 for fixed-path dependencies.
2. Refactor Sections 04-06 onto market-aware path resolution.
3. Confirm all active writes are market-partitioned.

### Phase 2 - Runner expansion
1. Extend the market runner to Sections 04-06.
2. Add downstream quality summaries to the manifest.
3. Dry-run one market before the two-market pilot.

### Phase 3 - Parcel requirement hardening
1. Define the manual parcel input contract.
2. Update parcel docs and Section 05 assumptions.
3. Confirm the contract matches the artifacts Section 05 actually reads.

### Phase 4 - Florida pilot closeout
1. Run the full two-market Florida pilot.
2. Review manifests, validation reports, and key visuals.
3. Publish closeout notes and update roadmap status.

## Risks

### Risk 1 - Hidden fixed-path dependencies
Sections 04-06 may still have hardcoded reads that only fail during multi-market runs.

Mitigation:
- audit first
- refactor before expanding the runner
- use one-market dry runs before the two-market pilot

### Risk 2 - Parcel contract/document mismatch
The documented parcel workflow may drift from what Section 05 actually consumes.

Mitigation:
- derive the contract from current code paths
- update Section 05 docs and parcel docs together
- review required fields against actual read logic

### Risk 3 - Sprint 3 scope creep
It will be tempting to automate parcel ETL or start Sprint 4 scoring work before Sprint 3 is actually closed.

Mitigation:
- keep parcel work contract-focused only
- defer scoring modularization to Sprint 4
- require final manifest plus doc updates before calling Sprint 3 complete

## Definition of Done
Sprint 3 is done when:

1. At least two Florida markets can be run through the full currently implemented pipeline from one command.
2. Sections 01-06 preserve artifacts independently by market for active writes.
3. A current batch manifest exists with runtime, pass/fail, output paths, and useful QA summaries.
4. Sections 04-06 no longer rely on shared fixed-path active inputs for market execution.
5. The manual parcel workflow remains manual, but its downstream requirements are explicit and hardened.
6. The roadmap, Sprint 3 plan, output contracts, and parcel docs all match reality.
