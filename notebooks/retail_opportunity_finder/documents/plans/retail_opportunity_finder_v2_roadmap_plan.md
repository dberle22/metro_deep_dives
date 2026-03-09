# Retail Opportunity Finder V2 Roadmap Plan

## Purpose
This roadmap translates the current ROF MVP into a scalable multi-market, multi-state system with stronger model governance and deeper decision visuals.

## Timebox and Sprint Cadence
- Sprint length: 2 weeks
- Total roadmap horizon: 7 sprints (14 weeks)
- Release checkpoints: end of Sprint 3 (Florida multi-market pilot), Sprint 5 (multi-state parcel platform), Sprint 7 (V2 release candidate)

## Strategic Outcomes
1. Clean, maintainable repository structure with clear ownership boundaries.
2. Configuration-driven market expansion (within Florida and across states).
3. Parameterized and versioned ranking framework that can be updated without deep code rewrites.
4. Deeper and more decision-useful visuals for tract, zone, and parcel prioritization.
5. Production-grade ingestion and parcel modeling for GA, SC, and NC.

## Initiative Map
- Initiative A: Platform and Repository Architecture
- Initiative B: Multi-Market and Multi-State Data Platform
- Initiative C: Ranking and Scoring Model Governance
- Initiative D: Visual Analytics and Deep Dives
- Initiative E: QA, Reliability, and Release Operations

## Sprint Plan

## Sprint 1 - Repository and SQL Foundation (Initiative A)
### Objectives
- Move SQL files into a dedicated, structured SQL directory.
- Standardize SQL path resolution across sections.
- Reduce top-level clutter and tighten source-of-truth boundaries.

### Scope
- Create `notebooks/retail_opportunity_finder/sql/` with:
  - `features/`
  - `qa/`
  - `staging/` (optional, for future intermediate transforms)
- Move:
  - `cbsa_features.sql`
  - `tract_features.sql`
  - `tract_universe.sql`
  - `tract_features_qa.sql`
- Add SQL path constants/registry in `_shared/config.R`.
- Refactor section scripts to use shared SQL paths instead of hardcoded file locations.
- Add `sql/README.md` for ownership and execution intent.

### Deliverables
- SQL directory refactor PR.
- Updated section scripts with no broken path references.
- SQL README and ownership notes.

### Exit Criteria
- No `.sql` files remain at ROF root.
- Section 01-03 data loads pass using new SQL paths.

## Sprint 2 - Market Configuration Abstraction (Initiatives A, B)
### Objectives
- Eliminate single-market hardcoding and centralize market metadata.
- Make market switching config-only for core pipelines.

### Scope
- Introduce `market_profile` config object (CBSA, state scope, benchmark region, peer set, labels).
- Replace Jacksonville/Florida-specific literals in section builds/checks where feasible.
- Parameterize benchmark and peer selection logic in Section 02.
- Add market label helpers for narrative-safe text injection.

### Deliverables
- New market config module.
- Refactored Section 02 market logic.
- Updated integration references to dynamic market labels.

### Exit Criteria
- Running with a different Florida CBSA requires config change only (no script edits).

## Sprint 3 - Florida Multi-Market Pipeline Pilot (Initiatives B, E)
### Objectives
- Prove reproducible batch execution across multiple Florida markets.
- Harden run/output partitioning by market.

### Scope
- Add orchestrator script for market batch runs.
- Parameterize output paths by market and run timestamp.
- Remove state-specific geometry table assumptions where possible (or isolate behind adapter).
- Pilot two Florida markets end-to-end (Jacksonville + one additional CBSA).

### Deliverables
- Batch run script and run manifest outputs.
- Two successful Florida market renders.
- Pilot summary with runtime and QA pass/fail status.

### Exit Criteria
- Two-market Florida run executes from one command and produces isolated artifacts.

## Sprint 4 - Ranking Engine Modularization and Versioning (Initiative C)
### Objectives
- Decouple scoring formulas from section scripts.
- Make ranking and shortlist weighting easier to update and audit.

### Scope
- Create shared scoring model registry:
  - tract scoring models (`v1`, `v2`, ...)
  - parcel shortlist weighting profiles
- Move weight vectors and component formulas out of Section 03/05 inline code.
- Add model metadata to output artifacts (model_id, version, component weights).
- Add sensitivity artifacts (top-N overlap, rank correlation across model variants).

### Deliverables
- `scoring_models` shared module.
- Refactored Section 03 and Section 05 scoring calls.
- Sensitivity comparison outputs.

### Exit Criteria
- Switching model versions is config-only.
- Artifacts clearly state which scoring model produced them.

## Sprint 5 - Multi-State Parcel Data Platform (GA, SC, NC) (Initiatives B, E)
### Objectives
- Build an entire sprint dedicated to out-of-state parcel ingestion and scalable parcel modeling/storage.
- Establish consistent cross-state parcel contracts and storage patterns.

### Scope
- Ingest parcel data for GA, SC, and NC into a standardized pipeline.
- Build state adapters for schema normalization (field mapping, geometry handling, QA flags).
- Create cross-state parcel canonical model (minimum required columns + optional extensions).
- Partition storage by `state`, `county`, `vintage`, and `run_id`.
- Add lineage metadata for source system, ingest date, and transform version.
- Add cross-state parcel QA checks (schema coverage, geometry validity, join readiness).
- Update Section 05 input layer to consume canonical parcel model regardless of state.

### Deliverables
- GA/SC/NC ingestion scripts and mapping specs.
- Canonical parcel model documentation and implementation.
- Cross-state parcel storage layout and manifest outputs.
- QA report pack for all three states.

### Exit Criteria
- GA, SC, and NC parcel inputs are ingested and queryable in canonical form.
- Section 05 can read canonical parcel inputs without state-specific code forks.

## Sprint 6 - Visual Deep Dives and Decision UX (Initiative D)
### Objectives
- Improve interpretability and actionability of outputs.
- Add deeper dives that explain why zones/parcels rank highly.

### Scope
- Add zone-level deep-dive cards (signal profile + rank drivers).
- Add tract/parcel score component contribution visuals.
- Add comparative visuals for cluster vs alternative zone strategy.
- Add standardized market context panel reusable across markets.
- Ensure visual contracts are stable for integration notebook use.

### Deliverables
- New visual objects and deep-dive outputs in sections 03-06.
- Updated integration notebook structure for deep-dive flow.
- Visual QA checklist updates.

### Exit Criteria
- Each market report includes baseline views + at least one standardized deep-dive section.

## Sprint 7 - Release Hardening and V2 Launch Candidate (Initiative E)
### Objectives
- Finalize testing, reproducibility, and release operations for V2.

### Scope
- Add automated integration checks for:
  - schema contracts
  - ranking determinism
  - cross-market/cross-state portability
- Add CI smoke run for selected markets.
- Publish runbook for onboarding a new market/state.
- Produce V2 release candidate render set.

### Deliverables
- CI workflow and test suite updates.
- New-market/new-state onboarding runbook.
- V2 release candidate outputs and QA summary.

### Exit Criteria
- CI passes for designated smoke markets.
- At least one non-Florida market completes end-to-end without code branching.

## Task-Level Execution Checklist (All Sprints)
Owner assignments below are role-based placeholders and should be mapped to named individuals at sprint kickoff.

## Owner Key
- `ENG-Data`: Data engineering lead
- `ENG-Analytics`: Analytics engineering lead
- `ENG-Spatial`: Spatial/parcels engineering lead
- `ENG-Model`: Scoring/modeling lead
- `ENG-Viz`: Visualization/reporting lead
- `ENG-QA`: QA/automation lead
- `PM`: Product/project owner

## Sprint 1 Checklist - Repository and SQL Foundation
- [ ] `S1-T1` Create `sql/features`, `sql/qa`, `sql/staging` directories. Owner: `ENG-Data`. Depends on: none.
- [ ] `S1-T2` Move all ROF root SQL files into new SQL structure. Owner: `ENG-Data`. Depends on: `S1-T1`.
- [ ] `S1-T3` Add shared SQL path registry in `_shared/config.R`. Owner: `ENG-Analytics`. Depends on: `S1-T1`.
- [ ] `S1-T4` Refactor Section 01-03 scripts to use registry paths. Owner: `ENG-Analytics`. Depends on: `S1-T2`, `S1-T3`.
- [ ] `S1-T5` Add `sql/README.md` with ownership and query intent. Owner: `ENG-Data`. Depends on: `S1-T2`.
- [ ] `S1-T6` Run smoke validation for Section 01-03 loads and checks. Owner: `ENG-QA`. Depends on: `S1-T4`.
- [ ] `S1-T7` Approve and merge SQL refactor PR. Owner: `PM`. Depends on: `S1-T5`, `S1-T6`.

## Sprint 2 Checklist - Market Configuration Abstraction
- [ ] `S2-T1` Design `market_profile` schema (CBSA, peers, region, labels, state scope). Owner: `ENG-Analytics`. Depends on: `S1-T7`.
- [ ] `S2-T2` Implement market config loader/helpers in shared module. Owner: `ENG-Analytics`. Depends on: `S2-T1`.
- [ ] `S2-T3` Refactor Section 02 benchmark + peer logic to config-driven inputs. Owner: `ENG-Analytics`. Depends on: `S2-T2`.
- [ ] `S2-T4` Replace hardcoded market labels in integration QMD with dynamic labels. Owner: `ENG-Viz`. Depends on: `S2-T2`.
- [ ] `S2-T5` Add tests for market config integrity and required fields. Owner: `ENG-QA`. Depends on: `S2-T2`.
- [ ] `S2-T6` Validate alternate Florida CBSA run via config-only switch. Owner: `ENG-QA`. Depends on: `S2-T3`, `S2-T4`, `S2-T5`.
- [ ] `S2-T7` Sign off market abstraction completion. Owner: `PM`. Depends on: `S2-T6`.

## Sprint 3 Checklist - Florida Multi-Market Pipeline Pilot
- [ ] `S3-T1` Build batch orchestrator for multi-market runs. Owner: `ENG-Analytics`. Depends on: `S2-T7`.
- [ ] `S3-T2` Add output partitioning by market + run id/timestamp. Owner: `ENG-Data`. Depends on: `S3-T1`.
- [ ] `S3-T3` Implement geometry-source adapter to reduce state-table hardcoding. Owner: `ENG-Spatial`. Depends on: `S2-T7`.
- [ ] `S3-T4` Configure and run Jacksonville + one additional Florida CBSA. Owner: `ENG-Analytics`. Depends on: `S3-T1`, `S3-T2`, `S3-T3`.
- [ ] `S3-T5` Produce pilot run manifest (runtime, pass/fail, artifact paths). Owner: `ENG-QA`. Depends on: `S3-T4`.
- [ ] `S3-T6` Approve Florida pilot checkpoint for release gate. Owner: `PM`. Depends on: `S3-T5`.

## Sprint 4 Checklist - Ranking Engine Modularization and Versioning
- [ ] `S4-T1` Define scoring model registry structure (tract + parcel model specs). Owner: `ENG-Model`. Depends on: `S3-T6`.
- [ ] `S4-T2` Implement scoring registry module with version IDs and metadata. Owner: `ENG-Model`. Depends on: `S4-T1`.
- [ ] `S4-T3` Refactor Section 03 to call registry-driven tract scoring. Owner: `ENG-Model`. Depends on: `S4-T2`.
- [ ] `S4-T4` Refactor Section 05 to call registry-driven shortlist scoring. Owner: `ENG-Model`. Depends on: `S4-T2`.
- [ ] `S4-T5` Add sensitivity outputs (top-N overlap, rank correlation). Owner: `ENG-Analytics`. Depends on: `S4-T3`, `S4-T4`.
- [ ] `S4-T6` Add tests for deterministic ranking and model metadata propagation. Owner: `ENG-QA`. Depends on: `S4-T3`, `S4-T4`.
- [ ] `S4-T7` Approve scoring v2 framework baseline. Owner: `PM`. Depends on: `S4-T5`, `S4-T6`.

## Sprint 5 Checklist - Multi-State Parcel Data Platform (GA, SC, NC)
- [ ] `S5-T1` Inventory GA/SC/NC source systems, schemas, and refresh cadence. Owner: `ENG-Spatial`. Depends on: `S3-T6`.
- [ ] `S5-T2` Define canonical cross-state parcel contract (required + optional columns). Owner: `ENG-Spatial`. Depends on: `S5-T1`.
- [ ] `S5-T3` Implement GA adapter and ingestion pipeline. Owner: `ENG-Spatial`. Depends on: `S5-T2`.
- [ ] `S5-T4` Implement SC adapter and ingestion pipeline. Owner: `ENG-Spatial`. Depends on: `S5-T2`.
- [ ] `S5-T5` Implement NC adapter and ingestion pipeline. Owner: `ENG-Spatial`. Depends on: `S5-T2`.
- [ ] `S5-T6` Implement partitioned storage/layout by state, county, vintage, run id. Owner: `ENG-Data`. Depends on: `S5-T3`, `S5-T4`, `S5-T5`.
- [ ] `S5-T7` Add lineage metadata and manifests for every state ingest. Owner: `ENG-Data`. Depends on: `S5-T6`.
- [ ] `S5-T8` Add cross-state parcel QA checks (schema coverage, geometry validity, join readiness). Owner: `ENG-QA`. Depends on: `S5-T3`, `S5-T4`, `S5-T5`, `S5-T7`.
- [ ] `S5-T9` Refactor Section 05 input layer to canonical parcel model only. Owner: `ENG-Analytics`. Depends on: `S5-T2`, `S5-T6`.
- [ ] `S5-T10` Validate one market run per new state using canonical parcel input. Owner: `ENG-QA`. Depends on: `S5-T8`, `S5-T9`.
- [ ] `S5-T11` Approve multi-state parcel platform checkpoint. Owner: `PM`. Depends on: `S5-T10`.

## Sprint 6 Checklist - Visual Deep Dives and Decision UX
- [ ] `S6-T1` Define deep-dive visual specs (zone cards, score drivers, comparison views). Owner: `ENG-Viz`. Depends on: `S4-T7`, `S5-T11`.
- [ ] `S6-T2` Implement section 03/05 component-contribution visuals. Owner: `ENG-Viz`. Depends on: `S6-T1`.
- [ ] `S6-T3` Implement zone-level deep-dive cards and comparison visuals. Owner: `ENG-Viz`. Depends on: `S6-T1`.
- [ ] `S6-T4` Update integration QMD flow to include deep-dive modules. Owner: `ENG-Viz`. Depends on: `S6-T2`, `S6-T3`.
- [ ] `S6-T5` Update visual contracts and output checks for new objects. Owner: `ENG-Analytics`. Depends on: `S6-T2`, `S6-T3`.
- [ ] `S6-T6` Run visual QA pass across sample markets. Owner: `ENG-QA`. Depends on: `S6-T4`, `S6-T5`.
- [ ] `S6-T7` Approve deep-dive UX baseline. Owner: `PM`. Depends on: `S6-T6`.

## Sprint 7 Checklist - Release Hardening and V2 Launch Candidate
- [ ] `S7-T1` Implement automated contract + determinism + portability tests in CI. Owner: `ENG-QA`. Depends on: `S6-T7`.
- [ ] `S7-T2` Add CI smoke runs for selected markets/states. Owner: `ENG-QA`. Depends on: `S7-T1`.
- [ ] `S7-T3` Publish new-market/new-state onboarding runbook. Owner: `ENG-Analytics`. Depends on: `S7-T2`.
- [ ] `S7-T4` Execute release-candidate run set (including non-Florida market). Owner: `ENG-Analytics`. Depends on: `S7-T2`.
- [ ] `S7-T5` Compile final QA summary and known issues log. Owner: `ENG-QA`. Depends on: `S7-T4`.
- [ ] `S7-T6` Approve V2 launch candidate and cut release tag. Owner: `PM`. Depends on: `S7-T3`, `S7-T5`.

## Dependency and Sequencing Rules
1. Sprint 1 must complete before broad refactors that touch SQL consumers.
2. Sprint 2 must complete before Sprint 3 batch orchestration to avoid rework.
3. Sprint 4 (scoring modularization) should complete before final deep-dive UX lock in Sprint 6.
4. Sprint 5 (multi-state parcels) is a standalone full sprint and is required before V2 launch hardening.

## Success Metrics
- Operational
  - Time to onboard a new Florida market reduced to under 1 day.
  - Time to onboard a new state parcel feed reduced to under 1 sprint.
- Technical
  - 100% section builds consume config-based paths and model definitions.
  - 0 state-specific forks in Section 05 canonical input logic.
- Analytical
  - Model version metadata present in 100% ranking artifacts.
  - Sensitivity outputs generated for every market run.
- Reporting
  - Deep-dive visuals rendered for every market output package.

## Risks and Mitigations
- Risk: Cross-state parcel schemas vary heavily.
  - Mitigation: state adapter layer + canonical contract + explicit nullable optional fields.
- Risk: Refactor introduces regressions in current Jacksonville path.
  - Mitigation: maintain Jacksonville as control market in every sprint smoke run.
- Risk: Visual expansion increases render fragility.
  - Mitigation: strict artifact contracts and integration-level visual key guards.

## Immediate Next Steps
1. Approve this roadmap as the working V2 plan.
2. Start Sprint 1 by implementing SQL refactor and shared SQL path registry.
3. Define Sprint 5 state-ingestion owners and source inventory early (before Sprint 3 ends).
