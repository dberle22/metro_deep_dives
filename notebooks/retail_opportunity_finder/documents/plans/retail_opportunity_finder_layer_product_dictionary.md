# Retail Opportunity Finder Layer Product Dictionary

## Purpose
This document is the first-pass unified dictionary for the Retail Opportunity Finder V2 rebuild. It maps the products described in the Layer sections of [retail_opportunity_finder_v2_architecture_review.md] to the actual DuckDB tables and section artifacts now present in the codebase.

It is meant to answer three questions:
- what each table or artifact is
- what job it performs in the pipeline
- whether it is already implemented, transitional, or still planned

## How To Read This
- `Layer` matches the architectural layer in the V2 review.
- `Logical product` is the architecture-level name or concept.
- `Physical product` is the actual DuckDB table or section artifact name.
- `Description` focuses on what the product is doing for us in the workflow, not just what its grain is.
- `Status` is one of:
  - `Implemented`
  - `Transitional`
  - `Planned`

## Conventions
- Current active market scope for the rebuild is `jacksonville_fl`.
- Geometry policy is mixed by design:
  - tract/county/CBSA geometry may be stored in DuckDB as `geom_wkt`
  - parcel geometry remains in county `.RDS` artifacts in the current slice
- Section artifacts remain valid compatibility outputs while the notebook is moving toward consumer-only behavior.

## Layer 2 - Upstream References And Platform Tables

| Layer | Logical product | Physical product | Grain | Description | Main logic / role | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2.0 Reference | Market profile dimension | `ref.market_profiles` | one row per `market_key` | Defines what a market is in ROF terms: its target CBSA, state scope, benchmark region, labels, and peer metadata. This is the root configuration table that tells every downstream layer what market it is building. | Materializes `MARKET_PROFILES` config into a reusable table. | All upstream layers, notebook runtime, QA | Implemented |
| 2.0 Reference | Market-to-CBSA membership | `ref.market_cbsa_membership` | one row per `market_key`, `cbsa_code`, `membership_type` | Tells us which CBSAs belong to a market context and whether they are the target or a peer. This is what lets metro comparison products know which rows to include in Jacksonville vs peer benchmarking. | Expands market config into target + peer membership rows. | Foundation overview logic, benchmarking, notebook context | Implemented |
| 2.0 Reference | Market-to-county membership | `ref.market_county_membership` | one row per `market_key`, `county_geoid` | Defines which counties belong to a market. This is the governing membership bridge that lets parcel publication be market-scoped without having to spatially join parcels into a market boundary. | Joins market profiles to county membership crosswalks. | Parcel standardization, county geometry selection, market-scoped filtering | Implemented |
| 2.0 Reference | County dimension | `ref.county_dim` | one row per `county_geoid` | Provides the standard county attributes used across markets: names, state IDs, area, and other reusable geography fields. | Normalized county lookup table. | Membership joins, QA, future serving tables | Implemented |
| 2.0 Reference | Tract dimension | `ref.tract_dim` | one row per `tract_geoid` | Provides the stable tract-to-county and tract naming lookup needed across scoring and geometry products. | Normalized tract lookup table. | Foundation, scoring, zones, QA | Implemented |
| 2.0 Reference | Land-use mapping | `ref.land_use_mapping` | one row per `land_use_code` | Governs parcel retail classification. This is the table that translates raw county land-use codes into a standardized category, description, `retail_flag`, and optional `retail_subtype`. | Combines the source code dictionary with reviewed overlay decisions from the Section 05 candidate mapping file. | Parcel standardization, Section 05, QA | Implemented |
| 2.0 QA | Reference QA results | `qa.ref_validation_results` | one row per QA check | Records whether the reference layer is structurally healthy enough to support downstream work. This gives us a central audit table for uniqueness, code formatting, and required-coverage checks. | Emits one validation row per reference-layer check. | Ops review, regression checks | Implemented |
| 2.0 QA | Unmapped land-use codes | `qa.ref_unmapped_land_use_codes` | one row per unresolved `land_use_code` | Shows which candidate land-use codes still lack a governed mapping. This is the operational to-do list for improving retail classification coverage. | Anti-join between candidate overlays and governed mapping. | Parcel governance, QA review | Implemented |

## Layer 2.1 - Foundation Feature Service

| Layer | Logical product | Physical product | Grain | Description | Main logic / role | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2.1 Foundation | Metro feature service | `foundation.cbsa_features` | one row per `cbsa_code`, `year` | Metro-level feature table for the market overview story. This is where the notebook gets Jacksonville-at-a-glance KPIs like population, growth, rent, home value, and commute metrics. | Builds and publishes DuckDB table `foundation.cbsa_features` from the table-owned asset `data_platform/layers/01_foundation_features/tables/cbsa_features/build.sql` plus market metadata. Downstream consumers should read the DuckDB table, not the build file. | Section 02, future metro snapshots | Implemented |
| 2.1 Foundation | Tract feature service | `foundation.tract_features` | one row per `market_key`, `tract_geoid`, `year` | Tract-level analytical feature table that feeds tract eligibility and scoring. This is the central “model input” table containing growth, density, price proxy, commute, income, gate flags, and other tract KPIs. | Renders and runs `tract_features.sql` for the active market/year. | Scoring layer, Section 03 compatibility path | Implemented |
| 2.1 Foundation | Market tract geometry | `foundation.market_tract_geometry` | one row per `market_key`, `tract_geoid` | Market-scoped tract geometry service. This is the geometry handoff used for maps, tract-level joins, and zone construction without forcing every section to re-query raw geometry sources. | Reads tract geometry, converts to `geom_wkt`, prepends market metadata. | Scoring, zones, Section 02/03/04 compatibility | Implemented |
| 2.1 Foundation | Market county geometry | `foundation.market_county_geometry` | one row per `market_key`, `county_geoid` | County geometry service for county outlines and context overlays in the notebook. | Reads county geometry, converts to `geom_wkt`, prepends market metadata. | Section 02, Section 05 map context | Implemented |
| 2.1 Foundation | Market CBSA geometry | `foundation.market_cbsa_geometry` | one row per `market_key`, `cbsa_code` | Market boundary geometry service for CBSA outline and context display. | Reads CBSA geometry, converts to `geom_wkt`, prepends market metadata. | Section 02 maps, future serving products | Implemented |
| 2.1 Foundation | Optional context layers | `foundation.context_cbsa_boundary`, `foundation.context_county_boundary`, `foundation.context_places`, `foundation.context_major_roads`, `foundation.context_water` | geometry row grain varies by source | These are notebook cartography helpers, not model inputs. They preserve the roads, places, and water layers needed to make the final visuals readable without re-owning context ingestion inside each section. | Reads existing Section 02 context artifacts and republishes them as DuckDB geometry tables where available. | Section 02, Section 05 visuals | Transitional |
| 2.1 QA | Foundation validation | `qa.foundation_validation_results` | one row per QA check | Audit table for required columns, key uniqueness, and geometry row presence in the foundation layer. | Emits structured QA results for foundation products. | Ops review, build validation | Implemented |
| 2.1 QA | Foundation null rates | `qa.foundation_null_rates` | one row per dataset-column pair | Tracks missingness in high-value feature columns so we can see whether gaps in rents, commute, income, or other metrics will distort downstream scoring. | Null-rate summary over `cbsa_features` and `tract_features`. | QA, model governance | Implemented |

## Layer 2.2 - Tract Scoring Service

| Layer | Logical product | Physical product | Grain | Description | Main logic / role | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2.2 Scoring | Tract scores | `scoring.tract_scores` | one row per `market_key`, `tract_geoid` | This is the tract ranking table for the funnel-to-zone pipeline. It scores every tract using the core model inputs: growth, housing pipeline, density headroom, price pressure, commute intensity, and income. Raw inputs are median-imputed where needed, converted to z-scores, weighted by the locked model weights, and summed into a final `tract_score`. The table also carries rank and “why tags” explaining which strengths a tract exhibits. | Uses `foundation.tract_features`; computes raw scoring variables, imputations, z-scores, weighted contributions, final score, rank, and narrative tags. | Zone build, Section 03, future sensitivity analysis | Implemented |
| 2.2 Scoring | Cluster seed tracts | `scoring.cluster_seed_tracts` | one row per `market_key`, `tract_geoid` | This is the reduced tract set used to seed the zone build. It keeps the top share of scored tracts so the zone layer works from the best tract candidates rather than the full market universe. | Selects the highest-ranked tracts based on `cluster_top_share` and records seed rank / cutoff metadata. | Zone build layer | Implemented |

## Layer 2.3 - Zone Build Service

| Layer | Logical product | Physical product | Grain | Description | Main logic / role | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2.3 Zones | Zone input candidates | `zones.zone_input_candidates` | one row per `market_key`, `tract_geoid` | This is the tract-level geometry-bearing candidate universe for zone construction. It is the subset of scored tracts that are both valid for geometry operations and selected as cluster seeds. | Joins scoring outputs to tract geometry, validates set consistency, and marks zone candidates. | Contiguity and cluster zone builders | Implemented |
| 2.3 Zones | Contiguity components | `zones.contiguity_zone_components` | one row per `market_key`, `tract_geoid` | This is the tract-to-component assignment table for strict touching zones. It tells us which candidate tracts fall into the same connected component when adjacency is defined by tract polygon touching. | Builds `st_touches()` adjacency, runs connected components, assigns component IDs and draft labels. | Contiguity summaries, contiguity geometries, comparison views | Implemented |
| 2.3 Zones | Contiguity zone summary | `zones.contiguity_zone_summary` | one row per `market_key`, `zone_id` | Summarizes each contiguity zone into an operationally readable submarket row. It turns a tract cluster into zone-level KPIs such as tract count, total population, weighted growth, median density, weighted housing pipeline, price proxy, and mean tract score. | Aggregates candidate-tract metrics by component-derived zone. | Section 04, future serving layer | Implemented |
| 2.3 Zones | Contiguity zone geometries | `zones.contiguity_zone_geometries` | one row per `market_key`, `zone_id` | Dissolved geometry table for strict contiguous zones. This is what makes the contiguity system mappable and lets downstream modules consume a stable zone polygon layer without re-dissolving tract geometry. | Dissolves component tracts, computes area and label points, stores geometry as `geom_wkt`. | Section 04, comparison views, possible serving consumers | Implemented |
| 2.3 Zones | Cluster assignments | `zones.cluster_assignments` | one row per `market_key`, `tract_geoid` | Tract-to-cluster assignment table for the proximity-based zone system. This is the default narrative zone system because it can group near-but-not-touching strong tracts into more operationally usable submarkets. | Uses projected tract centroids and distance-connected-components style clustering with configured `eps`, `min_pts`, and noise policy. | Cluster summaries, cluster geometries, Section 04, serving layer | Implemented |
| 2.3 Zones | Cluster zone summary | `zones.cluster_zone_summary` | one row per `market_key`, `cluster_id` | Zone-level KPI table for the cluster system. It describes each cluster zone in terms of tract count, population, weighted growth, density, housing pipeline, price, and mean tract quality. | Aggregates clustered tract metrics into zone summaries with ordering and labels. | Section 04, serving layer, shortlist scoring | Implemented |
| 2.3 Zones | Cluster zone geometries | `zones.cluster_zone_geometries` | one row per `market_key`, `cluster_id` | Dissolved polygon table for the cluster zones. This is the map-serving output that lets the notebook render stable cluster submarkets without recomputing clustering on the fly. | Dissolves clustered tract geometry and stores zone polygons as `geom_wkt`. | Section 04, Section 05 maps, serving layer | Implemented |

## Layer 2.4 - Parcel Standardization Service

| Layer | Logical product | Physical product | Grain | Description | Main logic / role | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2.4 Parcel | Canonical parcels | `parcel.parcels_canonical` | one row per `parcel_uid` | Canonical market-scoped parcel attribute table. This is the standardized parcel base for ROF: it filters the county parcel tabular universe down to the current market, normalizes county and parcel identifiers, preserves source county lineage, and keeps the core attributes used later for retail classification and shortlist scoring. Geometry is intentionally excluded in DuckDB for this slice. | Filters `rof_parcel.parcel_tabular_clean` by `ref.market_county_membership`, normalizes IDs, preserves market/county metadata, and attaches parcel attributes. | `parcel.retail_parcels`, Section 05, future serving layers | Implemented |
| 2.4 Parcel | Parcel join QA | `parcel.parcel_join_qa` | one row per `market_key`, `county_geoid` | County-grain QA bridge for parcel geometry readiness. This is what tells downstream consumers which county geometry artifacts are available and how cleanly geometry joined during the county parcel workflow. | Reads county QA artifacts from the standardized parcel root and reconciles them to market counties. | Section 05 geometry lookup, parcel lineage, QA review | Implemented |
| 2.4 Parcel | Parcel lineage | `parcel.parcel_lineage` | one row per `market_key`, `county_geoid` | County-grain operational lineage table for parcel publication. It records where the county parcel load came from, which load log entries contributed to the current market parcel set, and how many parcels were published per county. | Joins parcel QA, county load log, and canonical parcel counts into a publication lineage view. | Ops review, debugging, audit | Implemented |
| 2.4 Parcel | Retail parcels | `parcel.retail_parcels` | one row per `parcel_uid` | Retail-only subset of canonical parcels. This is the authoritative retail-classified parcel table, created by joining canonical parcels to the governed land-use mapping and filtering to `retail_flag = TRUE`. It is not a mixed parcel universe anymore. | Applies `ref.land_use_mapping` to `parcel.parcels_canonical` and retains true retail parcels only. | Serving layer, Section 05 | Implemented |
| 2.4 QA | Parcel validation | `qa.parcel_validation_results` | one row per QA check | QA summary for parcel publication health, such as key uniqueness, county coverage, and mapping readiness. | Emits one row per parcel-layer validation check. | Ops review, build validation | Implemented |
| 2.4 QA | Unmapped parcel use codes | `qa.parcel_unmapped_use_codes` | one row per unresolved `land_use_code` | Operational table showing land-use codes present in market parcels that still do not map cleanly to the governed land-use dictionary. | Anti-join between parcel use codes and `ref.land_use_mapping`. | Parcel governance, QA | Implemented |
| 2.4 Parcel | Parcel geometry artifacts | `<parcel_standardized_root>/county_outputs/*/parcel_geometries_analysis.rds` | one row per county parcel geometry | Geometry-bearing county parcel artifacts used for maps and late geometry attachment. These are intentionally not yet re-platformed into DuckDB. | Preserved output of the county parcel workflow. | Section 05, serving layer geometry joins | Transitional |

## Layer 2.5 - Market Serving Prep Service

| Layer | Logical product | Physical product | Grain | Description | Main logic / role | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2.5 Serving | Retail parcel tract assignment | `serving.retail_parcel_tract_assignment` | one row per retail `parcel_uid` | The one-time parcel-to-tract assignment table for retail parcels. This is what lets the notebook stop spatially joining each parcel to tracts during every Section 05 run. | Joins retail parcels with late-attached geometry to tract polygons and records assignment status. | `serving.retail_intensity_by_tract`, Section 05 consumer path | Implemented |
| 2.5 Serving | Retail intensity by tract | `serving.retail_intensity_by_tract` | one row per `market_key`, `tract_geoid` | Tract retail context table. It tells us how much retail signal already exists in each tract by combining retail parcel counts, retail area, tract land area, and percentile-based local context scores. This becomes the neighborhood retail signal used in overlay summaries and shortlist scoring. | Aggregates retail parcel assignments to tract level and derives percentile-based context scores. | `serving.parcel_zone_overlay`, `serving.parcel_shortlist`, Section 05 | Implemented |
| 2.5 Serving | Parcel-zone overlay | `serving.parcel_zone_overlay` | one row per `market_key`, `zone_system`, `zone_id` | Zone summary table that combines upstream tract quality with tract retail context. This is what tells us, for each zone, how many retail parcels it contains, how much retail area it has, how dense that retail area is, and how strong the underlying tract-quality signal is. | Inherits tract-to-zone membership from zone tables and rolls up tract retail intensity into zone-level overlay metrics. | Section 05, Section 06, future integration | Implemented |
| 2.5 Serving | Parcel shortlist | `serving.parcel_shortlist` | one row per `zone_system`, `parcel_uid` | Ranked parcel candidate table. This is the final parcel recommendation product: it combines zone quality, local tract retail context, and parcel characteristics into a `shortlist_score`, then ranks parcels both system-wide and within zone. The parcel-characteristics score uses parcel area, inverse value-per-square-foot signal, and sale recency. | Joins retail parcel attributes, tract assignment, tract retail context, and zone assignments; computes parcel-characteristics and final shortlist scores. | Section 05 notebook consumer, Section 06 summary | Implemented |
| 2.5 Serving | Parcel shortlist summary | `serving.parcel_shortlist_summary` | one row per `zone_system`, `zone_id` | Zone-level summary of the shortlist. This is the compact zone summary used to describe how many candidate parcels a zone has and what the top and average shortlist scores look like. | Aggregates shortlist candidates by zone. | Section 05 summaries, Section 06 | Implemented |
| 2.5 QA | Market serving validation | `qa.market_serving_validation_results` | one row per QA check | QA summary for the serving layer, including missing geometry after parcel attach, unassigned parcels, duplicate tract or zone rows, duplicate shortlist rows, and missing shortlist scores. | Emits validation rows over the serving products. | Ops review, Section 05 caveats | Implemented |

## Layer 3 - Downstream Section Artifacts

These are not DuckDB tables, but they are still part of the architecture because the integration notebook reads them directly during the transition.

### 3.1 Section 01 - Setup

| Layer | Logical product | Physical product | Grain | Description | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 3.1 Notebook | Run metadata | `section_01_run_metadata.rds` | one list per run | Run-level metadata and selected parameters used to label notebook outputs and QA. | Integration notebook | Implemented |
| 3.1 Notebook | Foundation payload | `section_01_foundation.rds` | one list per run | Shared setup payload including KPI dictionary and model parameters used by downstream sections. | Sections 02-06, integration | Implemented |

### 3.2 Section 02 - Market Overview

| Layer | Logical product | Physical product | Grain | Description | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 3.2 Notebook | Metro KPI tiles | `section_02_kpi_tiles.rds` | one row for target metro | Reader-facing KPI snapshot for Jacksonville. | Integration notebook | Implemented |
| 3.2 Notebook | Peer ranking table | `section_02_peer_table.rds` | one row per peer metro | Benchmark context table showing Jacksonville against peers. | Integration notebook | Implemented |
| 3.2 Notebook | Benchmark table | `section_02_benchmark_table.rds` | one row per benchmark geography | Raw KPI comparison for Jacksonville vs benchmark region vs U.S. | Integration notebook | Implemented |
| 3.2 Notebook | Population trend input | `section_02_pop_trend_indexed.rds` | one row per geography-year | Indexed trend data for the growth narrative. | Integration notebook | Implemented |
| 3.2 Notebook | Distribution input | `section_02_distribution_long.rds` | one row per metro-metric | Long-format metro comparison data for boxplots. | Integration notebook | Implemented |
| 3.2 Notebook | Section 02 visual bundle | `section_02_visual_objects.rds` | one list per run | Final render-ready plots and tables for the market overview section. | Integration notebook | Implemented |

### 3.3 Section 03 - Eligibility And Scoring

| Layer | Logical product | Physical product | Grain | Description | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 3.3 Notebook | Funnel counts | `section_03_funnel_counts.rds` | one row per gate step | Reader-facing funnel summary showing how many tracts remain after each eligibility gate. | Integration notebook | Implemented |
| 3.3 Notebook | Eligible tracts | `section_03_eligible_tracts.rds` | one row per eligible tract | Compatibility export of the eligible tract subset used in Section 03 visuals and QA. | Integration notebook, QA | Implemented |
| 3.3 Notebook | Scored tracts | `section_03_scored_tracts.rds` | one row per tract | Compatibility export of tract scores and score components used by Section 03 and Section 04. | Section 04, integration | Implemented |
| 3.3 Notebook | Top tracts | `section_03_top_tracts.rds` | one row per top tract | Reader-facing shortlist of the strongest tracts with why-tags. | Integration notebook, Section 06 | Implemented |
| 3.3 Notebook | Component score table | `section_03_tract_component_scores.rds` | one row per tract | Full audit table of tract raw inputs, z-scores, contributions, score, and rank. | QA, external review, Section 04 compatibility | Implemented |

### 3.4 Section 04 - Zones

| Layer | Logical product | Physical product | Grain | Description | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 3.4 Notebook | Zone input candidates | `section_04_zone_input_candidates.rds` | one row per tract candidate | Compatibility geometry-bearing tract candidate set for section-local zone building and QA. | Section 04 visuals/checks | Implemented |
| 3.4 Notebook | Contiguity zone summary/artifacts | `section_04_zone_summary.rds`, `section_04_zones.rds`, related outputs | zone or tract grain varies | Section-facing exports of the contiguity zoning system. | Integration notebook, comparison analysis | Implemented |
| 3.4 Notebook | Cluster zone summary/artifacts | `section_04_cluster_zone_summary.rds`, `section_04_cluster_zones.rds`, related outputs | zone or tract grain varies | Section-facing exports of the default cluster zoning system. | Section 05, integration notebook | Implemented |

### 3.5 Section 05 - Parcels And Shortlist

| Layer | Logical product | Physical product | Grain | Description | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 3.5 Notebook | Canonical zones | `section_05_zones_canonical.rds` | one row per zone polygon | Cluster-first geometry handoff used by the section visual path. | Section 05 visuals | Implemented |
| 3.5 Notebook | Canonical parcels | `section_05_parcels_canonical.rds` | one row per `parcel_uid` | Consumer-side parcel table with normalized parcel attributes. In the current refactor path this is intended to stay tabular and get geometry attached later only when needed. | Section 05 checks/build | Transitional |
| 3.5 Notebook | Retail classified parcels | `section_05_retail_classified_parcels.rds` | one row per parcel geometry | Geometry-bearing parcel table used for maps and downstream parcel outputs after late geometry attach. | Section 05 visuals/build | Transitional |
| 3.5 Notebook | Retail intensity | `section_05_retail_intensity.rds` | one row per tract | Section-facing retail context table, increasingly expected to mirror `serving.retail_intensity_by_tract`. | Section 05 checks, visuals | Transitional |
| 3.5 Notebook | Cluster zone overlay | `section_05_zone_overlay_cluster.rds` | one row per zone | Notebook-facing overlay summary, increasingly expected to mirror `serving.parcel_zone_overlay` filtered to cluster zones. | Section 05 visuals, Section 06 | Transitional |
| 3.5 Notebook | Cluster parcel shortlist | `section_05_parcel_shortlist_cluster.rds` | one row per shortlisted parcel geometry | Notebook-facing shortlist table with attached geometry for maps and tables, increasingly expected to consume `serving.parcel_shortlist` plus late geometry attach. | Section 05 visuals, Section 06, integration | Transitional |

### 3.6 Section 06 - Conclusion And Appendix

| Layer | Logical product | Physical product | Grain | Description | Main consumers | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 3.6 Notebook | Conclusion payload | `section_06_conclusion_payload.rds` | one list per run | Final narrative-ready package of zone highlights, shortlist summary, and next actions. | Integration notebook | Implemented |
| 3.6 Notebook | Appendix payload | `section_06_appendix_payload.rds` | one list per run | Notebook appendix package containing KPI definitions, assumptions, caveats, and QA rollups. | Integration notebook | Implemented |

## Current Architecture Notes

### Where the dictionary is strongest
- Reference, foundation, scoring, zones, and parcel tabular products are well-defined.
- Section artifact contracts are already explicit.
- The role of the current serving layer is clear enough to document.

### Where the dictionary is still light
- We do not yet have a column-by-column dictionary for every DuckDB table.
- Some serving-layer contracts still need to be reconciled with README notes written before shortlist publication was completed.
- Section 05 is actively transitioning from section-owned analytics to consumer-owned reads, so some section artifacts are intentionally marked `Transitional`.

## Recommended Next Follow-Up
Build a second document focused on column-level schema definitions for the highest-value tables first:
- `foundation.tract_features`
- `scoring.tract_scores`
- `zones.cluster_zone_summary`
- `parcel.parcels_canonical`
- `serving.retail_intensity_by_tract`
- `serving.parcel_zone_overlay`
- `serving.parcel_shortlist`
