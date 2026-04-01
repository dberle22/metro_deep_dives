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

## Bottom Line
The current ROF pipeline already has the beginnings of the right architecture: DuckDB-backed market and tract features upstream, section contracts downstream, and a market-aware integration layer.

The biggest remaining architectural gap is that Sections 04 and 05 still behave like computational engines. V2 should shift cluster construction, parcel standardization, retail classification, tract retail context, parcel-zone overlay, and shortlist ranking upstream so the notebook pipeline becomes a consumer of prepared analytical products rather than the place where those products are first created.
