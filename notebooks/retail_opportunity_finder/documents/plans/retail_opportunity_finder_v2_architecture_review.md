# Retail Opportunity Finder V2 Architecture Review

## Purpose
This document turns the current V2 direction into a reviewable architecture. It starts with upstream source systems, defines the upstream workflow layers that should prepare ROF-ready data products, and then maps how those products should service the downstream notebook sections and visuals.

It also documents the current build reality so we can see where the codebase already matches the target architecture and where logic still lives inside the R notebook pipeline.

## Architecture Goal
Move ROF V2 toward a layered system with clear boundaries:

1. Upstream sources provide raw and conformed data.
2. Upstream workflows build reusable market-ready analytical products in DuckDB.
3. Downstream section scripts read those prepared products, run section QA, and build visuals.
4. The integration notebook assembles the narrative from prepared section artifacts instead of acting like the primary computation engine.

## Design Principles
- Keep expensive spatial joins, land-use classification, and ranking logic upstream whenever they are reusable across runs.
- Treat DuckDB as the primary analytical serving layer for tabular and assignment products.
- Treat section `build/checks/visuals` scripts as report-serving modules, not raw ETL pipelines.
- Preserve market-aware output partitioning for notebook artifacts, visuals, and render payloads.
- Keep parcel standardization as a separate operational workflow from Section 05.

## Layer 1 - Upstream Sources

### Core market and tract sources
- ACS tract and metro features
- BPS housing supply inputs
- TIGER tract and county geometry
- Market profile metadata from shared config

### Parcel and land-use sources
- County parcel tabular extracts
- County parcel geometry extracts
- County join QA artifacts
- Manual retail land-use mapping inputs
- Parcel ingest manifest and county-level lineage metadata

### Context and reference sources
- CBSA boundaries
- County boundaries
- Places, roads, and water context layers
- Census geographic crosswalks, especially block-to-tract relationships where available

## Layer 2 - Upstream Workflows

## 2.1 Foundation Feature Service

### Purpose
Publish the tract- and metro-level feature tables that support market overview, tract scoring, and downstream market prep.

### Current build
- Section 02 reads `cbsa_features.sql` from DuckDB and constructs market overview artifacts in [section_02_build.R].
- Section 03 reads `tract_features.sql` from DuckDB and computes funnel, scoring, top tracts, and cluster seed tracts in [section_03_build.R].

### Current outputs
- Metro KPI tables and context geometries
- Tract eligibility and scoring artifacts
- Cluster seed tract set

### Target V2 role
This layer remains upstream and mostly already exists. The main future change is not structural but governance-related:
- move score formulas into a registry later
- keep the resulting tract-serving products in DuckDB and/or section artifacts
- make Section 03 more of a serving/export step than a scoring owner

### Proposed serving products
- `rof_market.cbsa_features`
- `rof_market.market_overview_snapshot`
- `rof_tract.tract_features`
- `rof_tract.tract_scores`
- `rof_tract.cluster_seed_tracts`

## 2.2 Cluster Zone Build Service

### Purpose
Build tract clusters and zone summaries before notebook execution so Section 04 becomes a reader and visualizer of prepared zone products.

### Current build
- Section 04 currently builds the candidate tract universe, contiguity graph, connected components, and zone summary inside [section_04_build.R].
- Section 04 cluster logic currently builds cluster assignments and cluster summaries inside [section_04_cluster_build.R].
- The outputs are persisted as section artifacts under `sections/04_zones/outputs/<market_key>/...`.

### Current responsibilities inside the notebook pipeline
- validate Section 03 tract inputs
- choose zone candidate tracts
- compute tract adjacency
- derive contiguity components
- derive cluster assignments
- build zone geometries and zone summaries

### Target V2 role
Move zone construction upstream into a dedicated cluster-zone workflow that stores tract-to-zone assignments and zone summary products in DuckDB. Section 04 should then:
- read prepared zone assignments and zone geometries
- run section QA on the prepared outputs
- generate the zone maps and zone summary visuals

### Proposed serving products
- `rof_tract.zone_candidate_tracts`
- `rof_tract.cluster_assignments`
- `rof_tract.cluster_zone_summary`
- `rof_tract.cluster_zone_geometries`
- `rof_tract.contiguity_zone_summary`
- `rof_tract.contiguity_zone_geometries`

### Key boundary
The notebook should not be the primary owner of clustering logic once V2 architecture is in place.

## 2.3 Parcel Standardization Service

### Purpose
Standardize county parcel inputs into a canonical parcel layer before the notebook runs.

### Current build
- The manual county ETL writes cleaned county outputs, geometry artifacts, and QA artifacts in [parcel_etl_manual_county_v2.R].
- Section 05 still reads county analysis RDS files, combines them into `parcels_raw`, then derives `parcels_canonical` inside [section_05_build.R].
- Section 05 still depends on a retail land-use mapping CSV artifact and classifies parcels at notebook runtime.

### Current responsibilities split across workflows
Upstream manual workflow currently handles:
- county tabular cleanup
- county geometry prep
- county join QA
- parcel analysis geometry outputs
- partial publishing into DuckDB

Section 05 currently still handles:
- combining county outputs across the market
- canonical parcel shaping for ROF consumption
- retail land-use mapping read and retail classification

### Target V2 role
Parcel standardization should become the source of truth for parcel-ready inputs. It should publish one canonical parcel-serving table per market scope or county batch, plus the supporting land-use classification tables.

### Proposed serving products
- `rof_parcel.parcels_canonical`
- `rof_parcel.land_use_mapping`
- `rof_parcel.retail_parcels`
- `rof_parcel.parcel_ingest_manifest`
- `rof_parcel.parcel_join_qa`

### Important contract change
Section 05 should stop rebuilding `parcels_raw` and `parcels_canonical` from county RDS files once this service is in place. It should read prepared parcel-serving tables instead.

### First-slice implementation decision
For the initial V2 platform transition, parcel standardization should reuse the existing DuckDB parcel tables for tabular serving outputs and keep parcel geometries in the existing `.RDS` analysis artifacts. This is an explicit design decision to reduce transition complexity, avoid unnecessary geometry re-materialization, and preserve compatibility with the current Section 05 spatial workflow while the parcel source-of-truth boundary is hardened.

Market membership for parcel publication should be assigned from county-to-CBSA reference membership tables, not from a parcel geometry join. Geometry artifacts remain important for downstream spatial analysis and QA, but they are not the source of truth for deciding whether a parcel belongs to a market.

## 2.4 Market Serving Prep Service

### Purpose
Prepare the parcel-zone analytical products that Section 05 currently computes on the fly.

### Current build
Section 05 currently does all of the following inside [section_05_build.R]:
- read cluster zones from Section 04 artifacts
- combine county parcel geometry artifacts
- canonicalize parcel attributes
- classify retail parcels from the manual land-use mapping
- assign retail parcels to tracts
- compute tract-level retail intensity
- join parcels to cluster zones
- compute zone overlay metrics
- score and rank the parcel shortlist

### Why this is the main V2 architecture bottleneck
This makes Section 05 both a report module and a heavy analytical processing step. It increases runtime, duplicates reusable logic, and leaves too much state in R objects instead of in stable upstream products.

### Target V2 role
Move reusable parcel-to-tract, parcel-to-zone, tract retail context, and shortlist logic upstream. This workflow should publish notebook-ready market products in DuckDB.

### Proposed serving products
- `rof_market.retail_intensity_by_tract`
- `rof_market.parcel_zone_overlay`
- `rof_market.parcel_shortlist`
- `rof_market.parcel_shortlist_summary`
- `rof_market.zone_retail_context`

### Preferred implementation notes
- Retail land-use classification should be attached upstream in `rof_parcel.retail_parcels`.
- Tract assignment should use parcel geography keys or crosswalks where possible instead of geometry joins at report time.
- Parcel-to-zone relationships and shortlist scores should be published before the notebook starts.
- Section 05 should attach parcel geometry late, as a lookup for final parcel maps and shortlist/map artifacts, rather than using geometry as the default analytical engine.

## Layer 3 - Downstream Section Pipeline

## 3.1 Section 01 - Setup

### Current role
- initialize runtime
- persist run metadata and model/foundation payloads

### Target role
Remain lightweight. This section is already close to the desired architecture.

## 3.2 Section 02 - Market Overview

### Current role
- query metro features from DuckDB
- create KPI tables, benchmark tables, distribution inputs, and market geometry/context artifacts
- build overview visuals

### Current architecture fit
Mostly aligned. Section 02 is already a clean consumer of upstream feature tables.

### Downstream consumers
- Section 05 visuals use market/county/context geometry artifacts
- integration notebook uses Section 02 tables and visuals

## 3.3 Section 03 - Eligibility and Scoring

### Current role
- query tract features from DuckDB
- apply gates and scoring
- build top tracts and cluster seed tract products
- build tract-scoring visuals

### Current architecture fit
Partially aligned. The data source is upstream, but the scoring logic still lives inside the section build.

### Downstream consumers
- Section 04 uses scored tracts, tract geometry, component scores, and cluster seed tracts
- Section 06 uses top tracts and validation outputs

## 3.4 Section 04 - Zones

### Current role
- build zone candidates
- build contiguity zones
- build cluster zones
- compute zone summaries
- build zone visuals

### Current architecture fit
Not yet aligned. Section 04 is still the owner of zone construction logic.

### Target role
- read zone assignments and zone summaries from the Cluster Zone Build Service
- validate those products
- render zone maps and summary visuals

### Visual products this section should still own
- zone maps
- cluster zone maps
- zone summary tables
- cluster-vs-contiguity comparison visuals

## 3.5 Section 05 - Parcels

### Current role
- read parcel geometry artifacts from the parcel standardized root
- build canonical parcels
- classify retail parcels
- compute tract retail intensity
- join parcels to cluster zones
- score and rank shortlist candidates
- build parcel overlay and shortlist visuals

### Current architecture fit
Not aligned. Section 05 is the most overloaded section in the current design.

### Target role
- read prepared parcel-serving tables and parcel-zone products from DuckDB
- run section-level QA and contract checks
- build overlay maps, shortlist tables, and parcel visuals

### Visual products this section should still own
- market parcel context map
- cluster parcel overlay map
- shortlist map
- parcel shortlist tables and summary displays

### What should move upstream
- parcel canonicalization
- retail land-use mapping lookup
- retail classification
- parcel-to-tract assignment
- tract-level retail intensity
- parcel-to-zone overlay logic
- shortlist scoring and ranking

## 3.6 Section 06 - Conclusion and Appendix

### Current role
- read the final tract, zone, and parcel artifacts
- assemble highlights, QA rollups, assumptions, and recommendations
- build appendix visuals/tables

### Current architecture fit
Aligned. Section 06 is already acting like a downstream consumer and synthesis layer.

## Layer 4 - Integration Notebook and Visual Assembly

### Current build
The integrated notebook at [retail_opportunity_finder_mvp.qmd] now reads market-aware section artifacts via shared path helpers.

### Target role
The integration notebook should remain an orchestration and narrative layer only:
- read section outputs
- render text, tables, and figures
- avoid owning analytical transformations beyond light formatting

## Upstream-to-Downstream Service Map

| Upstream product | Current build owner | Current downstream consumer | Target build owner | Target downstream consumer |
| --- | --- | --- | --- | --- |
| Metro feature table | DuckDB SQL + Section 02 | Section 02 visuals, integration | Foundation Feature Service | Section 02 |
| Tract feature table | DuckDB SQL + Section 03 | Section 03, Section 04 | Foundation Feature Service | Section 03, Cluster Zone Build Service |
| Tract scores | Section 03 | Section 04, Section 06 | Foundation Feature Service or scoring service | Section 03, Section 04, Section 06 |
| Cluster seed tracts | Section 03 | Section 04 | Foundation Feature Service or scoring service | Cluster Zone Build Service, Section 04 |
| Cluster assignments | Section 04 cluster build | Section 05 | Cluster Zone Build Service | Section 04, Market Serving Prep |
| Cluster zone summary | Section 04 cluster build | Section 05, Section 06 | Cluster Zone Build Service | Section 04, Section 05, Section 06 |
| Canonical parcels | Section 05 from county RDS files | Section 05 checks/visuals | Parcel Standardization Service | Section 05, Market Serving Prep |
| Land-use mapping | Manual CSV read in Section 05 | Section 05 | Parcel Standardization Service | Parcel Standardization Service, Market Serving Prep |
| Retail parcel classification | Section 05 | Section 05 visuals | Parcel Standardization Service | Market Serving Prep, Section 05 |
| Retail intensity by tract | Section 05 | Section 05, Section 06 | Market Serving Prep | Section 05, Section 06 |
| Parcel-zone overlay | Section 05 | Section 05, Section 06 | Market Serving Prep | Section 05, Section 06 |
| Parcel shortlist | Section 05 | Section 05, Section 06 | Market Serving Prep | Section 05, Section 06 |

## Current-State Build Map

### Already close to the target architecture
- Section 02 already behaves like a DuckDB-backed serving consumer.
- Section 06 already behaves like a downstream synthesis layer.
- Market-aware artifact partitioning now supports downstream sections.

### Partially aligned
- Section 03 has upstream data inputs but still owns scoring logic.
- Parcel standardization exists as a separate manual workflow, but Section 05 still rebuilds too much parcel-serving state locally.

### Not yet aligned
- Section 04 still owns zone generation.
- Section 05 still owns parcel classification, parcel-to-tract context, parcel-to-zone overlay, and parcel shortlist ranking.

## Target DuckDB Serving Layout

### `rof_market`
- Market overview snapshots
- Final market-ready parcel-zone overlay products
- Final shortlist products
- Final tract retail intensity products

### `rof_tract`
- Tract features
- Tract scores
- Cluster seed tracts
- Cluster assignments
- Zone summaries

### `rof_parcel`
- Canonical parcels
- Parcel ingest manifests
- Land-use mapping
- Retail parcel classification
- Parcel QA and lineage tables

## Recommended Build Sequence

1. Formalize the upstream product contracts in DuckDB.
2. Move cluster assignment and cluster zone summary generation out of Section 04 and into an upstream workflow.
3. Move parcel canonicalization and retail land-use classification fully upstream.
4. Move retail intensity, parcel-zone overlay, and shortlist ranking into a market-serving workflow.
5. Refactor Section 04 and Section 05 to read prepared products rather than build them.
6. Keep Section 06 and the integration notebook as synthesis and presentation layers.

## Review Questions
- Do we want Section 03 tract scoring to remain section-owned for Sprint 3 closeout, or should scoring products also move upstream as part of this architecture phase?
- Do we want contiguity zones to remain a first-class upstream product, or demote them to comparison-only support artifacts?
- Should parcel-serving outputs be materialized per market, per county batch, or both?
- Which DuckDB tables should become the formal source of truth for review and QA signoff?

## Decisions From Review

### 1. Tract scoring moves upstream
Tract scoring should become an upstream workflow. The report should read prepared tract scoring outputs instead of computing them inside Section 03.

Implications:
- scoring formulas move out of section-owned build logic
- multiple scoring models can be materialized upstream
- the notebook can select a scoring model or default model without recomputing scores

### 2. Contiguity zones also move upstream
Contiguity zones should be built upstream alongside cluster zones.

Implications:
- both zone systems become reusable analytical products
- the notebook can include or exclude contiguity outputs without paying the computational cost at render time
- zone comparison remains available for validation and future narrative choices

### 3. Parcel-serving outputs should be county-based with market columns
Parcel-serving outputs should be materialized at county granularity, while carrying market identifiers needed for market-level stitching.

Implications:
- county remains the operational build unit
- market-level analysis can be assembled efficiently through relational filters
- one parcel table can support multiple market definitions where county overlap exists

### 4. Table lineage mapping is required before final source-of-truth decisions
We should define a proposed lineage map before assigning final system-of-record and QA signoff responsibilities.

## Proposed Build Plan

## Repository Structure Proposal

### Goal
Separate upstream data-product workflows from downstream notebook/report assembly so the repo mirrors the architecture.

### Proposed top-level structure inside `notebooks/retail_opportunity_finder/`

- `data_platform/`
- `notebook_build/`
- `sections/_shared/`
- `documents/`
- `sql/`

### `data_platform/`
This becomes the home for upstream workflows and their contracts.

Proposed structure:
- `data_platform/README.md`
- `data_platform/contracts/`
- `data_platform/layers/`
- `data_platform/qa/`
- `data_platform/orchestration/`

### `data_platform/contracts/`
Defines stable product contracts and lineage docs.

Proposed contents:
- `duckdb_schemas.md`
- `table_lineage_map.md`
- `product_contracts/`
- `qa_contracts/`

### `data_platform/layers/`
One folder per upstream layer.

Proposed structure:
- `data_platform/layers/00_reference_membership/`
- `data_platform/layers/01_foundation_features/`
- `data_platform/layers/02_tract_scoring/`
- `data_platform/layers/03_zone_build/`
- `data_platform/layers/04_parcel_standardization/`
- `data_platform/layers/05_market_serving_prep/`

Within each layer:
- `README.md`
- `sql/`
- `R/`
- `qa/`
- `outputs/` if temporary local artifacts are needed

### `data_platform/orchestration/`
Holds runner scripts that execute layers in order.

Proposed contents:
- `run_foundation_features.R`
- `run_tract_scoring.R`
- `run_zone_build.R`
- `run_parcel_standardization.R`
- `run_market_serving_prep.R`
- `run_market_pipeline.R`

### `notebook_build/`
This becomes the home for notebook-serving code and render orchestration.

Proposed structure:
- `notebook_build/README.md`
- `notebook_build/sections/`
- `notebook_build/integration/`
- `notebook_build/render/`

### `notebook_build/sections/`
One folder per notebook section, but these become consumer modules rather than heavy processing modules.

Proposed structure:
- `notebook_build/sections/01_setup/`
- `notebook_build/sections/02_market_overview/`
- `notebook_build/sections/03_eligibility_scoring/`
- `notebook_build/sections/04_zones/`
- `notebook_build/sections/05_parcels/`
- `notebook_build/sections/06_conclusion_appendix/`

Within each section:
- `section_XX_inputs.R`
- `section_XX_checks.R`
- `section_XX_visuals.R`
- `section_XX_contract.md`

The key change:
- `inputs.R` replaces much of the current heavy `build.R`
- heavy analytics should already exist upstream in DuckDB or prepared artifacts

### `notebook_build/integration/`
Contains the integrated `.qmd` render layer and any notebook-wide helpers.

Proposed contents:
- `qmd/retail_opportunity_finder_v2.qmd`
- `R/load_section_artifacts.R`
- `R/render_helpers.R`

## DuckDB Schema Proposal

### Goal
Use one schema per logical layer so table ownership is clear and lineage is easy to follow.

### Proposed schemas

#### `raw_ext`
External raw landing references where needed.

Examples:
- raw county parcel tabular loads
- raw county parcel geometry metadata
- raw manual mapping imports

#### `ref`
Reference and dimension tables.

Examples:
- market profiles
- market-to-county membership
- market-to-cbsa membership
- county dimensions
- tract dimensions
- census block to tract crosswalks
- land-use mapping lookup tables

#### `foundation`
Conformed feature tables used across multiple downstream workflows.

Examples:
- metro feature tables
- tract feature tables
- context feature tables
- common geometry serving tables

#### `scoring`
Upstream tract scoring products.

Examples:
- scored tracts by model
- eligibility funnels by model
- top tracts by model
- cluster seed tracts by model
- scoring model registry tables

#### `zones`
All zone-system build products.

Examples:
- contiguity assignments
- contiguity summaries
- cluster assignments
- cluster summaries
- zone geometry tables
- zone comparison outputs

#### `parcel`
County-based parcel standardization and retail classification products.

Examples:
- canonical parcels
- parcel QA tables
- parcel lineage manifests
- retail parcel flags
- land-use mapping coverage summaries

#### `serving`
Notebook-ready market and parcel-zone products.

Examples:
- retail intensity by tract
- parcel-zone overlay
- parcel shortlist
- parcel shortlist summaries
- market overview snapshots when materialized for serving

#### `qa`
Persistent QA and audit tables.

Examples:
- workflow run manifests
- schema validation results
- row-count checks
- contract pass/fail tables
- publish approvals

## Layer-by-Layer Build Proposal

## Layer 1 - Foundation Features

### Responsibility
Build conformed tract, metro, and geography-serving tables.

### Repo location
- `data_platform/layers/01_foundation_features/`

### DuckDB schemas used
- reads from `raw_ext` and `ref`
- writes to `foundation`
- writes QA to `qa`

### Example outputs
- `foundation.cbsa_features`
- `foundation.tract_features`
- `foundation.market_tract_geometry`
- `foundation.market_county_geometry`
- `foundation.context_layers`

## Layer 2 - Tract Scoring

### Responsibility
Compute tract eligibility, scoring, ranking, and model variants upstream.

### Repo location
- `data_platform/layers/02_tract_scoring/`

### DuckDB schemas used
- reads from `foundation` and `ref`
- writes to `scoring`
- writes QA to `qa`

### Example outputs
- `scoring.tract_scores`
- `scoring.tract_score_components`
- `scoring.tract_funnel_counts`
- `scoring.top_tracts`
- `scoring.cluster_seed_tracts`
- `scoring.model_registry`

### Notes
- this layer replaces the current section-owned scoring logic in Section 03
- multiple models should be stored with `model_id` and `model_version`

## Layer 3 - Zone Build

### Responsibility
Build both contiguity and cluster zone systems upstream.

### Repo location
- `data_platform/layers/03_zone_build/`

### DuckDB schemas used
- reads from `scoring`, `foundation`, and `ref`
- writes to `zones`
- writes QA to `qa`

### Example outputs
- `zones.contiguity_assignments`
- `zones.contiguity_zone_summary`
- `zones.contiguity_zone_geometry`
- `zones.cluster_assignments`
- `zones.cluster_zone_summary`
- `zones.cluster_zone_geometry`
- `zones.zone_system_comparison`

### Notes
- this layer absorbs the heavy build logic currently sitting in Section 04
- both zone systems should share a common contract where possible

## Layer 4 - Parcel Standardization

### Responsibility
Standardize parcel data by county, attach retail land-use mapping, and publish parcel-serving tables.

### Repo location
- `data_platform/layers/04_parcel_standardization/`

### DuckDB schemas used
- reads from `raw_ext` and `ref`
- writes to `parcel`
- writes QA to `qa`

### Example outputs
- `parcel.parcels_canonical`
- `parcel.parcel_lineage`
- `parcel.parcel_join_qa`
- `parcel.retail_land_use_mapping`
- `parcel.retail_parcels`

### Notes
- county should be the build grain
- every row should carry county identifiers and market membership columns
- this layer should absorb the current land-use CSV dependency from Section 05

## Layer 5 - Market Serving Prep

### Responsibility
Build notebook-ready market products from scored tracts, zones, and parcel-serving tables.

### Repo location
- `data_platform/layers/05_market_serving_prep/`

### DuckDB schemas used
- reads from `scoring`, `zones`, `parcel`, `foundation`, and `ref`
- writes to `serving`
- writes QA to `qa`

### Example outputs
- `serving.market_overview_snapshot`
- `serving.retail_intensity_by_tract`
- `serving.parcel_zone_overlay`
- `serving.parcel_shortlist`
- `serving.parcel_shortlist_summary`

### Notes
- this layer absorbs the heaviest analytical logic currently in Section 05
- tract joins should prefer keys and crosswalks over report-time geometry joins whenever possible

## Notebook Build Proposal

### Goal
Keep notebook code focused on reading prepared products, validating section inputs, and rendering visuals.

### Section responsibilities after refactor

#### Section 02
- read market overview serving tables
- render KPI and context visuals

#### Section 03
- read tract scoring tables
- render scoring tables, maps, and explanations

#### Section 04
- read contiguity and cluster zone products
- render zone maps and comparisons

#### Section 05
- read parcel, overlay, intensity, and shortlist products
- render parcel maps and shortlist views

#### Section 06
- read the final prepared section artifacts
- build narrative summary and appendix

### Important notebook rule
The `.qmd` should not own heavy spatial or ranking computation. It should consume prepared products through section input modules.

## Proposed Table Lineage Map

### Purpose
Define the first-pass lineage needed before finalizing source-of-truth and QA ownership.

### Core lineage chains

#### Market overview chain
`raw_ext/ref -> foundation.cbsa_features -> serving.market_overview_snapshot -> notebook_build/sections/02_market_overview`

#### Tract scoring chain
`raw_ext/ref -> foundation.tract_features -> scoring.tract_scores + scoring.tract_score_components + scoring.top_tracts -> notebook_build/sections/03_eligibility_scoring`

#### Zone build chain
`foundation.tract_features + scoring.cluster_seed_tracts + foundation.market_tract_geometry -> zones.cluster_assignments + zones.cluster_zone_summary + zones.contiguity_assignments + zones.contiguity_zone_summary -> notebook_build/sections/04_zones`

#### Parcel canonicalization chain
`raw_ext county parcel loads + ref.land_use_mapping + ref.market_membership -> parcel.parcels_canonical + parcel.retail_parcels + parcel.parcel_join_qa -> serving inputs`

#### Parcel shortlist chain
`parcel.retail_parcels + scoring.tract_scores + zones.cluster_assignments/zones.cluster_zone_summary + ref.block_tract_crosswalk -> serving.retail_intensity_by_tract + serving.parcel_zone_overlay + serving.parcel_shortlist -> notebook_build/sections/05_parcels`

#### Final report chain
`serving + section QA artifacts -> notebook_build sections -> integrated qmd render -> publish outputs`

## Proposed Ownership and Source-of-Truth Starting Point

### Candidate source-of-truth domains
- `foundation.*` for conformed tract and metro features
- `scoring.*` for tract scoring outputs by model
- `zones.*` for both zone-system analytical products
- `parcel.*` for county-based parcel and retail-classification products
- `serving.*` for notebook-ready report inputs
- `qa.*` for persistent validation history and signoff status

### What still needs review before locking
- whether geometry tables should live beside each schema or in a shared geometry-serving schema
- whether `serving.market_overview_snapshot` should be materialized or remain section-built from `foundation.cbsa_features`
- whether shortlist outputs should be persisted only at county grain, only at market grain, or in both forms

## Recommended Implementation Sequence

1. Create the repo folders for `data_platform/` and `notebook_build/`.
2. Write the DuckDB schema contract doc and table naming rules.
3. Build the `ref` tables for market membership, land-use mapping, and geography crosswalks.
4. Move tract scoring into `Layer 2 - Tract Scoring`.
5. Move cluster and contiguity zone generation into `Layer 3 - Zone Build`.
6. Move parcel canonicalization and retail assignment into `Layer 4 - Parcel Standardization`.
7. Build `Layer 5 - Market Serving Prep` for tract intensity, parcel-zone overlay, and parcel shortlist products.
8. Refactor notebook sections to read prepared products from these layers.
9. Add persistent QA manifests in `qa`.
10. Define formal source-of-truth tables and signoff checkpoints once the lineage map is validated in practice.

## Concrete Execution Plan

### Planning assumptions
- We are building this as a staged refactor, not a one-shot rewrite.
- The current notebook pipeline should remain runnable while upstream layers are introduced.
- We should migrate one responsibility area at a time and preserve market-aware outputs during the transition.
- We should prioritize stable table contracts before broad notebook refactors.

## Epic 1 - Platform Skeleton and Contracts

### Goal
Create the repo and database skeleton that the rest of the architecture will build on.

### Deliverables
- `data_platform/` folder structure
- `notebook_build/` folder structure
- DuckDB schema creation scripts
- naming and contract conventions
- initial lineage and ownership docs

### Tasks
- [x] `E1-T1` Create `data_platform/` with `contracts/`, `layers/`, `qa/`, and `orchestration/`.
- [x] `E1-T2` Create `notebook_build/` with `sections/`, `integration/`, and `render/`.
- [x] `E1-T3` Add a DuckDB bootstrap script that creates `raw_ext`, `ref`, `foundation`, `scoring`, `zones`, `parcel`, `serving`, and `qa` schemas.
- [x] `E1-T4` Write `duckdb_schemas.md` with table naming conventions, required metadata columns, and geometry handling rules.
- [x] `E1-T5` Write `table_lineage_map.md` with the first formal lineage map for all major products.
- [x] `E1-T6` Define standard run metadata fields: `run_id`, `run_ts`, `market_key`, `state_abbr`, `county_fips`, `model_id`, `model_version`, `source_vintage`.

### Exit criteria
- Repo skeleton exists.
- DuckDB schemas can be initialized from one script.
- Layer/table naming rules are documented.

## Epic 2 - Reference and Membership Layer

### Goal
Build the shared reference tables that upstream layers need to join consistently.

### Deliverables
- market membership tables
- geography crosswalk tables
- land-use mapping reference tables
- shared dimensions

### Tasks
- [x] `E2-T1` Create `ref.market_profiles` from the active market profile config.
- [x] `E2-T2` Create `ref.market_county_membership` with `market_key`, `state_abbr`, `county_fips`, `county_name`.
- [x] `E2-T3` Create `ref.market_cbsa_membership` and confirm benchmark/peer relationships.
- [x] `E2-T4` Create `ref.county_dim`, `ref.tract_dim`, and any reusable geography dimensions needed for joins.
- [x] `E2-T5` Create `ref.block_tract_crosswalk` or document the preferred tract-assignment input if blocks already exist on parcels.
- [x] `E2-T6` Move the retail land-use mapping into `ref.land_use_mapping` with versioning and review metadata.
- [x] `E2-T7` Add QA checks for duplicate memberships, invalid FIPS, missing market keys, and unmapped land-use codes.

### Exit criteria
- Shared reference tables exist in DuckDB.
- County-to-market membership is queryable and reusable across layers.
- Land-use mapping is no longer notebook-local CSV state.

## Epic 3 - Foundation Feature Layer

### Goal
Stabilize the conformed tract, metro, and context-serving products.

### Deliverables
- `foundation` feature tables
- market geometry serving tables
- foundation QA manifests

### Tasks
- [x] `E3-T1` Move current metro feature logic into `data_platform/layers/01_foundation_features/`.
- [x] `E3-T2` Publish `foundation.cbsa_features` with explicit data-vintage metadata.
- [x] `E3-T3` Publish `foundation.tract_features` with stable column contracts matching current Section 03 needs.
- [x] `E3-T4` Publish `foundation.market_tract_geometry` and `foundation.market_county_geometry`.
- [x] `E3-T5` Publish context-serving tables for boundaries, roads, places, and water where needed.
- [x] `E3-T6` Add row-count, key, null-rate, and geometry QA outputs to `qa.foundation_*`.
- [x] `E3-T7` Refactor Section 02 consumers to read foundation/serving products through a dedicated input module.

### Exit criteria
- Section 02 can read from the new foundation-serving layer without changing report behavior.
- Foundation QA outputs exist and are persisted.

## Epic 4 - Upstream Tract Scoring Layer

### Goal
Move tract scoring out of Section 03 and into a dedicated upstream service.

### Deliverables
- scoring workflow scripts
- scoring model registry tables
- tract score and component tables
- cluster seed outputs

### Tasks
- [x] `E4-T1` Create `data_platform/layers/02_tract_scoring/`.
- [ ] `E4-T2` Define the tract scoring registry table structure with `model_id`, `model_version`, weights, gates, and active flags.
- [x] `E4-T3` Implement upstream scoring workflow that writes `scoring.tract_scores`.
- [ ] `E4-T4` Publish `scoring.tract_score_components`, `scoring.tract_funnel_counts`, `scoring.top_tracts`, and `scoring.cluster_seed_tracts`.
- [ ] `E4-T5` Add QA checks for deterministic ranking, required fields, and missing component rates.
- [x] `E4-T6` Refactor Section 03 to consume scoring outputs rather than compute them.
- [x] `E4-T7` Preserve compatibility with the current report by keeping artifact names stable where practical.

### Exit criteria
- Section 03 no longer owns tract scoring logic.
- Multiple scoring models can be materialized upstream.

## Epic 5 - Upstream Zone Build Layer

### Goal
Move both contiguity and cluster zone construction out of Section 04.

### Deliverables
- zone build workflow scripts
- assignment tables
- zone summaries
- geometry tables
- comparison outputs

### Tasks
- [x] `E5-T1` Create `data_platform/layers/03_zone_build/`.
- [x] `E5-T2` Implement upstream contiguity-zone build using scored tract inputs and tract geometry.
- [x] `E5-T3` Implement upstream cluster-zone build using cluster seed tracts and tract geometry.
- [x] `E5-T4` Publish standardized assignment and summary tables for both zone systems.
- [x] `E5-T5` Publish geometry-serving tables for both zone systems.
- [ ] `E5-T6` Publish `zones.zone_system_comparison`.
- [ ] `E5-T7` Add QA checks for one-to-one tract assignment, positive area, label determinism, and geometry validity.
- [x] `E5-T8` Refactor Section 04 to consume upstream zone products and only build visuals/checks.

### Exit criteria
- Section 04 no longer builds zones.
- Both contiguity and cluster systems are queryable upstream.

## Epic 6 - Upstream Parcel Standardization Layer

### Goal
Move canonical parcel shaping and retail assignment upstream at county grain.

### Deliverables
- county-based canonical parcel tables
- parcel lineage tables
- retail parcel classification outputs
- parcel QA products

### Tasks
- [x] `E6-T1` Create `data_platform/layers/04_parcel_standardization/`.
- [x] `E6-T2` Formalize the county-grain parcel contract with required fields, types, and QA flags.
- [x] `E6-T3` Publish `parcel.parcels_canonical` with county identifiers and market membership columns.
- [x] `E6-T4` Publish `parcel.parcel_lineage` and `parcel.parcel_join_qa`.
- [x] `E6-T5` Replace the notebook-local retail mapping dependency with `ref.land_use_mapping`.
- [x] `E6-T6` Publish `parcel.retail_parcels` with retail flags, subtype fields, and mapping-version metadata.
- [x] `E6-T7` Add QA checks for join coverage, missing keys, unmapped use codes, invalid geometries, and county anomalies.

### Exit criteria
- Section 05 no longer builds `parcels_raw` and `parcels_canonical`.
- Retail classification becomes an upstream parcel product.

## Epic 7 - Upstream Market Serving Prep Layer

### Goal
Move tract retail context, parcel-zone overlay, and shortlist ranking out of Section 05.

### Deliverables
- serving tables for tract retail intensity
- serving tables for parcel-zone overlay
- serving tables for parcel shortlist and summaries
- market-serving QA products

### Tasks
- [ ] `E7-T1` Create `data_platform/layers/05_market_serving_prep/`.
- [x] `E7-T1` Create `data_platform/layers/05_market_serving_prep/`.
- [x] `E7-T2` Implement tract assignment logic using parcel geography keys/crosswalks instead of report-time spatial joins where possible.
- [x] `E7-T3` Publish `serving.retail_intensity_by_tract`.
- [x] `E7-T4` Publish `serving.parcel_zone_overlay` for both contiguity and cluster systems.
- [ ] `E7-T5` Publish `serving.parcel_shortlist` with `model_id`, `model_version`, `zone_system`, and market/county identifiers.
- [ ] `E7-T6` Publish `serving.parcel_shortlist_summary`.
- [x] `E7-T7` Add QA checks for tract assignment completeness, zone coverage, shortlist rank determinism, and duplicate parcel handling.
- [x] `E7-T8` Refactor Section 05 to consume serving tables and only handle checks/visuals.

### Exit criteria
- Section 05 no longer owns retail intensity, parcel-zone overlay, or shortlist computation.
- Market-serving products are ready before notebook render begins.

## Epic 8 - Notebook Build Refactor

### Goal
Restructure the notebook code so sections are consumers of prepared products.

### Deliverables
- `notebook_build/` section modules
- section input readers
- integration render flow that reads prepared artifacts

### Tasks
- [ ] `E8-T1` Create `notebook_build/sections/` module structure with one folder per section.
- [ ] `E8-T2` Convert current heavy `build.R` responsibilities into `inputs.R` readers where upstream layers exist.
- [ ] `E8-T3` Keep section `checks.R` as the notebook-facing contract validator for prepared inputs.
- [ ] `E8-T4` Keep section `visuals.R` as the render layer for prepared inputs.
- [ ] `E8-T5` Create a new integrated notebook path under `notebook_build/integration/`.
- [ ] `E8-T6` Add shared notebook readers/helpers for DuckDB-backed prepared products and market-aware artifact writes.
- [ ] `E8-T7` Migrate the current QMD to the new structure without changing output behavior more than necessary.

### Exit criteria
- The notebook render path is primarily a consumer path.
- Heavy analytics no longer live in `.qmd` or notebook section build scripts.

## Epic 9 - QA, Lineage, and Release Operations

### Goal
Make lineage, QA, and source-of-truth ownership explicit enough for review and release decisions.

### Deliverables
- persistent QA tables
- workflow run manifests
- table-level lineage docs
- source-of-truth review proposal

### Tasks
- [ ] `E9-T1` Create persistent `qa.workflow_runs` and `qa.validation_results` tables.
- [ ] `E9-T2` Add one QA output contract per upstream layer.
- [ ] `E9-T3` Add one publish/signoff checklist per major serving product family.
- [ ] `E9-T4` Extend the table lineage map with upstream job name, direct parents, grain, and owner for each table.
- [ ] `E9-T5` Propose source-of-truth tables for each product family after lineage is validated in practice.
- [ ] `E9-T6` Add notebook-facing validation summaries so Section 06 can surface pipeline health from `qa` tables.

### Exit criteria
- Every major product has a lineage record and QA history.
- Source-of-truth discussions can happen against documented lineage rather than assumptions.

## Suggested Delivery Waves

### Wave 1 - Skeleton and references
- Epic 1
- Epic 2

### Wave 2 - Stable tract and zone products
- Epic 3
- Epic 4
- Epic 5

### Wave 3 - Stable parcel and market-serving products
- Epic 6
- Epic 7

### Wave 4 - Notebook migration and release hardening
- Epic 8
- Epic 9

## Recommended First Build Slice

If we want the highest-leverage first implementation slice, build this sequence first:

1. Epic 1 skeleton and schema bootstrap
2. Epic 2 reference tables
3. Epic 4 upstream tract scoring
4. Epic 5 upstream zone build
5. Refactor Section 03 and Section 04 consumers

That gives us a clean first vertical slice where tract scoring and zone systems are fully upstream before we tackle the more operational parcel work.

## New Agent Prompt

Use the following prompt to start a fresh implementation agent:

```text
You are continuing the Retail Opportunity Finder V2 architecture refactor in `/Users/danberle/Documents/projects/metro_deep_dive`.

Start by reading these documents for context:
- `notebooks/retail_opportunity_finder/documents/plans/retail_opportunity_finder_v2_architecture_review.md`
- `notebooks/retail_opportunity_finder/documents/plans/retail_opportunity_finder_v2_roadmap_plan.md`
- `notebooks/retail_opportunity_finder/documents/plans/sprint_3_implementation_plan.md`

Architecture decisions already made:
- Tract scoring moves upstream into a dedicated workflow and should be stored in DuckDB.
- Both contiguity zones and cluster zones move upstream into a dedicated zone-build workflow.
- Parcel-serving outputs should be materialized at county grain, with market columns included for easy market-level stitching.
- We need explicit DuckDB schemas, repo folder structure, lineage mapping, and QA contracts before final source-of-truth decisions.

Target repo direction:
- Add a `data_platform/` area with layer folders:
  - `01_foundation_features`
  - `02_tract_scoring`
  - `03_zone_build`
  - `04_parcel_standardization`
  - `05_market_serving_prep`
- Add a `notebook_build/` area where section modules become consumers of prepared data instead of heavy processing owners.
- Use DuckDB schemas:
  - `raw_ext`
  - `ref`
  - `foundation`
  - `scoring`
  - `zones`
  - `parcel`
  - `serving`
  - `qa`

Your task is to begin implementation with the first build slice:
1. Create the platform skeleton and schema bootstrap.
2. Create the initial reference/membership layer contracts.
3. Begin moving tract scoring upstream.
4. Begin moving zone build upstream.

Working rules:
- Preserve the current runnable ROF pipeline while introducing the new structure.
- Prefer additive changes and compatibility shims over breaking rewrites.
- Use market-aware outputs consistently.
- Treat the notebook as a downstream consumer.
- Update docs as you go when contracts become clearer.
- Do not automate the full parcel ETL in this first slice.

Expected outputs for this turn:
- the new repo folders and bootstrap files
- initial DuckDB schema bootstrap implementation
- initial contract docs for schemas and lineage
- first upstream scoring/zone scaffolding or implementation if feasible
- a concise progress summary with what was created, what remains, and any blockers
```

## Current Status After Florida Parcel Refresh

### What is now in better shape
- Florida county tabular rebuilds have now been run through the manual parcel ETL with the refreshed county identifiers and census block field.
- Parcel standardization now has a stronger county-grain source table for `rof_parcel.parcel_tabular_clean`.
- Layer 04 parcel standardization already publishes canonical parcel, parcel QA, lineage, and retail parcel products into DuckDB.
- Layer 05 market serving prep already publishes tract assignment, tract retail intensity, and parcel-zone overlay products upstream.

### What still keeps Section 05 heavier than it should be
- Section 05 still loads parcel geometry artifacts very early in D1 and rebuilds a geometry lookup even when canonical parcel attributes are already available upstream.
- Section 05 still carries fallback tract assignment logic based on `st_point_on_surface()` plus `st_join(..., st_within)` when serving assignment/intensity tables are missing.
- Section 05 still carries fallback parcel-to-zone assignment logic based on parcel points joined to cluster geometries when serving shortlist products are missing.
- Section 05 still retains notebook-local shortlist scoring and ranking because Layer 05 does not yet publish `serving.parcel_shortlist` and `serving.parcel_shortlist_summary`.

### Remaining heavy spatial joins to remove first
1. Remove the Section 05 fallback parcel-to-tract spatial join once `serving.retail_parcel_tract_assignment` is treated as required input rather than optional fallback input.
2. Remove the Section 05 fallback parcel-to-zone spatial join once `serving.parcel_shortlist` is published upstream.
3. Delay parcel geometry loading in Section 05 until after prepared shortlist and overlay products are already selected, so geometry is only joined for final map-serving outputs.
4. Keep geometry-based work inside upstream operational layers only where no stable geography key exists yet.

## Recommended Finish Sequence

### 1. Finish Epic 7 before broader notebook refactors
The cleanest path is to complete the missing upstream serving products before doing another large Section 05 cleanup pass.

Immediate targets:
- implement Layer 05 publication of `serving.parcel_shortlist`
- implement Layer 05 publication of `serving.parcel_shortlist_summary`
- publish shortlist QA against duplicate parcel-zone rows, missing scores, and rank determinism
- mark `E7-T5` and `E7-T6` complete once these tables are materialized

Reason:
- this removes the last major reason Section 05 still needs parcel-level spatial fallback logic for cluster candidate generation

### 2. Refactor Section 05 into a strict consumer path
Once shortlist tables are upstream, Section 05 should stop treating serving tables as optional.

Refactor targets in [section_05_build.R]:
- make `parcel.parcels_canonical`, `parcel.retail_parcels`, `serving.retail_parcel_tract_assignment`, `serving.retail_intensity_by_tract`, `serving.parcel_zone_overlay`, and `serving.parcel_shortlist` required inputs
- delete the fallback tract assignment block that uses parcel points and tract geometry
- delete the fallback parcel-to-zone block that uses parcel points and cluster zone geometry
- stop recomputing retail-intensity percentiles locally when `serving.retail_intensity_by_tract` is present
- reduce D1 to contract checks, geometry lookup assembly, and artifact persistence for downstream visuals only

### 3. Narrow the role of geometry in Section 05
Geometry should remain available for maps, but not as the engine for analytical recomputation.

Target boundary:
- DuckDB tables own parcel attributes, tract assignment, tract retail context, zone overlay, and shortlist ranking
- county `.RDS` geometry artifacts only provide parcel shapes for map display and geometry-bearing exports
- Section 05 joins geometry onto already-ranked prepared parcel outputs near the end of the build

### 4. Align the document task list with actual current state
The architecture plan should reflect that Epic 7 is materially farther along than the checklist currently implies.

Recommended task status updates:
- keep `E7-T5` and `E7-T6` open until shortlist tables are truly published
- treat `E7-T8` as only partially complete until Section 05 fallback spatial joins are removed
- make `E8-T2` the next notebook-facing milestone after Epic 7 shortlist publication

### 5. Suggested implementation order for the next coding pass
1. Finish shortlist publication in Layer 05.
2. Run Layer 05 and confirm `serving.parcel_shortlist` and `serving.parcel_shortlist_summary` exist for the active market.
3. Refactor Section 05 to require serving inputs and delete the tract and zone spatial fallback branches.
4. Move parcel geometry attachment closer to the final visual/output assembly path.
5. Re-run Section 05 and compare artifacts against the current output contract to confirm no narrative regressions.

## Bottom Line
The current ROF pipeline already has the beginnings of the right architecture: DuckDB-backed market and tract features upstream, section contracts downstream, and a market-aware integration layer.

The biggest remaining architectural gap is that Sections 04 and 05 still behave like computational engines. V2 should shift cluster construction, parcel standardization, retail classification, tract retail context, parcel-zone overlay, and shortlist ranking upstream so the notebook pipeline becomes a consumer of prepared analytical products rather than the place where those products are first created.
