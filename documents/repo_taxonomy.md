# Metro Deep Dive Repo Taxonomy

This document defines the current taxonomy of the repository, what the repo does today, and the highest-priority next steps by major goal area.

It is intentionally practical. The aim is to distinguish:

- what already exists and is working,
- what exists in partial form,
- what is still future-state,
- where each area should live in the repository.

## What This Repo Does

`metro_deep_dive` is a shared analytics and product workspace for metro-level data products, spatial analyses, reporting, and reusable platform assets.

Today, the repository serves four functions:

1. It is a home for reusable analytics infrastructure.
2. It is the active development repo for the Retail Opportunity Finder (`ROF`) product.
3. It contains secondary analysis tracks and prototypes.
4. It stores published and intermediate output artifacts.

The current repo is not a single linear pipeline. It is better understood as a platform repo with one primary product and several adjacent workstreams.

## Top-Level Taxonomy

### 1. Shared Platform Assets

Purpose:
- reusable code, standards, documentation, and schema/context assets used across analyses and products.

Primary locations:
- `R/`
- `scripts/`
- `schemas/`
- `documents/database_design/`
- `documents/visual_library/`

Current state:
- real but unevenly organized
- some assets are mature enough to reuse
- some are still design documents or early scaffolds

### 2. Product: Retail Opportunity Finder

Purpose:
- identify, score, zone, and shortlist retail opportunity areas and parcels by market.

Primary locations:
- `notebooks/retail_opportunity_finder/`
- `docs/rof-mvp/`

Current state:
- clearest and most mature product in the repo
- has modular section architecture, integration flow, output contracts, and publish path
- already has working artifacts and a public-site payload

### 3. Secondary Analysis Tracks

Purpose:
- support domain-specific analyses that may remain standalone or later become products.

Primary locations:
- `notebooks/tx_school_districts/`
- `notebooks/national_analyses/`
- `outputs/analyses/`

Current state:
- real work exists here
- less structured and less productized than ROF

### 4. Published and Generated Outputs

Purpose:
- store rendered outputs, publish payloads, section artifacts, and other non-source deliverables.

Primary locations:
- `outputs/`
- `docs/rof-mvp/`
- `notebooks/retail_opportunity_finder/sections/*/outputs/`
- `notebooks/retail_opportunity_finder/integration/outputs/`

Current state:
- active and important
- conventions are split between product publish outputs, general analysis outputs, and section-local artifacts

## Goal-Based Taxonomy

The sections below map the intended goals of the repo to what exists already and what should happen next.

### Goal 1. Clean ETL and Database Structure

Intent:
- create a clear ingestion and transformation layer centered in `scripts/etl/`
- define stable database responsibilities and storage layers
- make this the canonical path for loading and modeling data used by products and analyses

Where this belongs:
- `scripts/etl/`
- `documents/database_design/`
- possibly `config/` for shared path/runtime config

What exists already:
- `scripts/etl/create_DB.R`
- database design docs under `documents/database_design/`
- SQL assets inside `notebooks/retail_opportunity_finder/sql/`
- data/analytics benchmark files used by non-ROF analysis work

Read of current state:
- the design intent exists
- the implementation is fragmented
- there is not yet one obvious ETL system that the whole repo uses
- ROF currently has its own SQL and data-access patterns rather than sitting on a clearly repo-wide ETL platform

Highest-priority next steps:
- define the canonical database architecture in one place:
  - raw/staging
  - cleaned/silver
  - analysis-ready/gold
  - product-specific marts if needed
- turn `scripts/etl/` into a real workflow directory with named responsibilities:
  - ingest
  - standardize
  - model
  - QA
  - publish
- document how ROF SQL inputs map to those layers
- decide which tables are shared platform tables versus product-specific tables
- replace ad hoc or legacy ETL notes with one operator-facing runbook

### Goal 2. Reusable Functions and Utilities

Intent:
- build a common shared code layer for repeated data, spatial, scoring, and visualization logic

Where this belongs:
- `R/`
- `scripts/utils.R`
- product-local shared folders only when truly product-specific

What exists already:
- reusable functions in `R/`
- visual helpers in `R/visual/`
- ROF shared runtime and helpers in `notebooks/retail_opportunity_finder/sections/_shared/`

Read of current state:
- this already exists in meaningful form
- the main problem is not absence, it is split ownership
- some logic that should probably be repo-shared lives inside ROF-local shared code

Highest-priority next steps:
- define a rule for what belongs in `R/` versus product-local `_shared/`
- move non-ROF-specific helpers out of ROF `_shared/` into `R/`
- create a short shared-code index documenting major functions and owners
- standardize helper naming and file purpose so people can find things quickly

### Goal 3. Data Dictionary and Context Layer

Intent:
- create a semantic layer that explains fields, metrics, data sources, model assumptions, and usage conventions for humans and AI agents

Where this belongs:
- `schemas/data_dictionary/`
- `documents/`

What exists already:
- `schemas/data_dictionary/`
- documentation in `documents/database_design/`
- ROF section contracts and planning docs
- visual contracts and standards docs

Read of current state:
- strong directional alignment
- this is one of the repo's most important platform opportunities
- the ingredients exist, but they are distributed across many files instead of being presented as one coherent context layer

Highest-priority next steps:
- define the scope of the data dictionary:
  - fields
  - derived metrics
  - tables
  - business definitions
  - source lineage
- connect the data dictionary to actual tables and artifacts used by ROF and other analyses
- create a top-level context-layer README explaining how agents and users should use these docs
- document product-specific dictionaries separately when needed, but keep shared metric definitions centralized

### Goal 4. Visual Library

Intent:
- provide shared visual standards, chart contracts, and reusable chart code

Where this belongs:
- `documents/visual_library/`
- `R/visual/`

What exists already:
- visual library planning docs
- chart contract files
- benchmark defaults and standards docs
- initial visual helper code in `R/visual/`
- chart-type directories under `documents/visual_library/charts/`

Read of current state:
- clearly intentional and already structured
- more mature as a design/governance layer than as a full implementation library

Highest-priority next steps:
- finish the minimum viable visual library contract:
  - spec
  - contract
  - prep function
  - render function
  - sample output
- pick a small number of high-value chart types and complete them end to end
- refactor existing script-level visuals to use shared prep/render functions where practical
- define how ROF visuals relate to the shared visual library rather than remaining a parallel system

### Goal 5. Retail Opportunity Finder

Intent:
- build a clear, scalable product for market screening, tract scoring, zone generation, parcel prioritization, and final report publishing

Where this belongs:
- `notebooks/retail_opportunity_finder/`
- `docs/rof-mvp/`

What exists already:
- modular sections `01` through `06`
- shared runtime/config/helpers
- SQL feature queries
- integration scripts and validation summaries
- published MVP payload
- planning, sprint, and improvement docs
- parcel standardization workflow for Section 05

Read of current state:
- this is the flagship product in the repo
- it is already real, not speculative
- sections 01-03 are more clearly generalized for multi-market use than 04-06
- later stages still carry some transitional logic and output conventions

Highest-priority next steps:
- preserve ROF as the primary product boundary in the repo taxonomy
- continue moving ROF to config-driven, market-partitioned execution
- separate source artifacts from generated outputs more clearly
- align ROF shared logic with repo-wide platform standards where it makes sense
- keep product docs centralized and concise so new contributors can understand ROF without reading sprint history first

### Goal 6. Texas School District Analysis

Intent:
- maintain or expand a separate domain analysis track focused on school district scoring and reporting

Where this belongs:
- `notebooks/tx_school_districts/`
- `outputs/analyses/tx_school_districts/`

What exists already:
- at least two notebooks
- at least one rendered output map

Read of current state:
- partial and valid
- currently closer to a focused analysis track than a product

Highest-priority next steps:
- decide whether this stays a standalone analysis area or becomes a product line
- add a local README explaining inputs, outputs, and purpose
- identify which pieces can reuse shared ETL, dictionary, and visual assets

### Goal 7. Quick Demographic Analyses and Future Chatbot

Intent:
- answer data questions quickly using a combination of reusable data assets, metric definitions, and standard visual generation

Where this belongs:
- shared platform layer first
- future app/tool layer later

What exists already:
- overview and national analysis work
- ACS/database design thinking
- data dictionary direction
- visual library direction
- published outputs and reusable R functions

Read of current state:
- this is not built yet
- the prerequisite ingredients are emerging in the repo
- this idea makes sense precisely because the repo is already evolving into a semantic + visual + data platform

Highest-priority next steps:
- define the minimum viable question-answering system:
  - what questions it answers
  - what tables it can use
  - what visuals it can generate
  - what documentation/context it should cite
- make the data dictionary and visual library machine-readable enough to support this later
- avoid building the chatbot before the context/data/visual layers are stable enough to support it

### Goal 8. Centralized Published Outputs

Intent:
- make it obvious where final deliverables live and how they differ from intermediate artifacts

Where this belongs:
- `docs/` for web-published payloads
- `outputs/` for general rendered deliverables
- section-local outputs only for product internals and reproducible intermediates

What exists already:
- `docs/rof-mvp/` as a clear web publish target
- `outputs/` for general analysis outputs
- ROF section and integration outputs

Read of current state:
- this exists, but conventions are mixed
- outputs are currently spread across multiple levels for good reasons, but with little central policy

Highest-priority next steps:
- define a repo-wide output policy:
  - source code
  - intermediate artifacts
  - publish-ready outputs
  - archived outputs
- treat `docs/` as public/published payload only
- treat `outputs/` as repo-level rendered deliverables
- keep section-local outputs only where they are required for reproducibility and downstream composition

## Recommended Repo Frame

If the repo were explained in plain language, the cleanest description would be:

`metro_deep_dive` is a shared analytics platform and product workspace with:

- a shared data, documentation, and visual foundation,
- one flagship product (`ROF`),
- several secondary analysis tracks,
- and a growing semantic layer intended to support both human users and future AI-assisted workflows.

## Current Priority Order

If the goal is to organize the repo without boiling the ocean, the most important next steps are:

1. Create a truthful repo entry point.
   - The top-level README should describe the repo as it exists now, not as an earlier generic pipeline.

2. Formalize the repo taxonomy.
   - Make the platform/product/analysis/output split explicit.

3. Strengthen the shared platform boundary.
   - Clarify ETL ownership, shared utilities, data dictionary scope, and visual library scope.

4. Keep ROF clearly separated as the flagship product.
   - Avoid mixing ROF sprint history, section internals, and repo-wide platform docs.

5. Define output and publish policy.
   - Make it easy to tell what is source, what is intermediate, and what is final.

## Suggested Documentation Ownership

To keep the repo understandable, documentation should be grouped by function:

- repo-level taxonomy and orientation:
  - `documents/repo_taxonomy.md`
- shared data/database/context documentation:
  - `documents/database_design/`
  - `schemas/data_dictionary/`
- shared visual standards:
  - `documents/visual_library/`
- product-specific docs:
  - `notebooks/retail_opportunity_finder/documents/`
- analysis-specific local docs:
  - colocated with each analysis area when needed

## Bottom Line

The repo already supports the direction you described.

What exists now is not disorder without pattern. It is an emerging platform repo whose parts are at different maturity levels:

- `ROF` is a real product.
- shared code and visual standards are partially real platform assets.
- ETL/database structure needs the most architectural tightening.
- the data dictionary/context layer is a high-value platform opportunity.
- the future chatbot idea is plausible, but it depends on getting the platform layers cleaner first.
