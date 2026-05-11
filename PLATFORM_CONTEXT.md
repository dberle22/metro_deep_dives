# Metro Deep Dive — Platform Context

This document is the shared context anchor for work across the Metro Deep Dive platform and its related project repos. It is written to give an AI agent or new collaborator a complete working picture without needing to read the full repo.

---

## What This Platform Is

`metro_deep_dive` is a shared analytics platform and product workspace for US metro-level and national demographic and economic data products.

It serves four functions:

1. **Shared platform** — reusable ETL, analytics functions, documentation, and a visual system used across products and analyses
2. **Active product development** — Retail Opportunity Finder (flagship), US Demographic Chatbot (in development), Texas School District analysis (secondary)
3. **Data warehouse** — a medallion architecture DuckDB warehouse built from public US datasets
4. **Semantic and visual infrastructure** — a data dictionary, metric catalog, and visual library intended to support both human workflows and AI-assisted analytics

---

## Data Architecture

### Medallion Layers

| Layer | Purpose | Location |
|---|---|---|
| Bronze | Raw extracts, source CSVs, API outputs — preserved as-is | `data/` |
| Staging | Source-shaped landed tables; one family doc per source/theme, not one doc per geography replica | `scripts/etl/staging/`, `schemas/data_dictionary/layers/staging/` |
| Silver | Standardized, lightly transformed, analysis-ready wide tables with consistent geo/time keys | `scripts/etl/silver/`, `schemas/data_dictionary/layers/silver/` |
| Gold | Curated cross-domain marts and decision-ready KPIs; primary query target for products | `scripts/etl/gold/`, `schemas/data_dictionary/layers/gold/` |

**Key conventions:**
- Silver ACS tables follow a `<theme>_base` / `<theme>_kpi` pair pattern
- Gold default grain is always `(geo_level, geo_id, geo_name, year)` — `period` is reserved for non-ACS economic series
- Gold is built in DuckDB SQL first; R is used only where SQL becomes procedurally awkward
- CBSA is derived from 2023 Census county membership with county-to-CBSA rebasing

### Geography Hierarchy

```
Census Tract → County → CBSA → State → Division → Region → US
```

All Gold tables carry `(geo_level, geo_id, geo_name, year)` as the primary key grain. Crosswalks live in `silver.xwalk_*` tables.

**Supported geography grains:** US, Region, Division, State, CBSA, County, Census Place, Census Tract, ZCTA

---

## Data Sources In Scope

| Source | What It Provides |
|---|---|
| ACS (Census Bureau) | Age, race, education, income, labor, housing, migration, transportation, social infrastructure — 5-year rolling estimates via `tidycensus` |
| BEA Regional API | GDP by metro, personal income, Regional Price Parity (MARPP) |
| BLS | Labor force and unemployment (LAUS); QCEW is a later candidate |
| BPS (Census Bureau) | Building permits by metro |
| HUD | Fair Market Rent (FMR), rent burden (CHAS) |
| Zillow | ZHVI (home values), ZORI (observed rent index) — public CSVs |
| IRS | County-to-county migration flows — planned v1.1 |
| TIGER/Line + Census | Geography geometries, crosswalk tables |
| Later candidates | FEMA, FHFA, NOAA, CHR, IPEDS |

---

## Gold Layer — Current Tables

These Gold tables are implemented and documented in `schemas/data_dictionary/layers/gold/`:

| Table | Domain | Key Inputs |
|---|---|---|
| `gold.population_demographics` | Population, age, race, education | ACS |
| `gold.economics_income_wide` | Income, earnings, RPP | ACS, BEA |
| `gold.economics_gdp_wide` | GDP by metro | BEA |
| `gold.economics_labor_wide` | Labor force, unemployment | ACS, BLS LAUS |
| `gold.economics_industry_wide` | Sector shares, HHI, GDP by industry | BEA |
| `gold.housing_core_wide` | Vacancy, tenure, rent, home value, permits, burden | ACS, HUD FMR, BPS |
| `gold.affordability_wide` | Rent-to-income, value-to-income, FMR gap | Gold housing + income |
| `gold.migration_wide` | ACS mobility shares, nativity (IRS flows deferred) | ACS |
| `gold.transport_built_form_wide` | Drive alone, transit, WFH, commute time, no-vehicle | ACS |
| `gold.tx_isd_metrics` | Texas school district metrics | ACS + ISD data |

**Normalization supplements:** Separate supplemental Gold tables for z-scores, percentiles, and min-max values — not embedded in base marts.

---

## Advanced Composite Scores (Planned)

These scores are in design; none are in production yet. They depend on completing base Gold marts and getting weights approved.

- `affordability_score` — rent/value to income, burden, FMR gap, RPP adjustment
- `housing_market_overheating_index` — price/rent growth vs income growth, permit intensity, vacancy trend
- `economic_strength_index` — income per capita, real GDP growth, employment strength
- `industry_concentration_score` — sector shares, HHI, location quotients
- `migration_attractiveness_score` — inflow/outflow, net migration, origin breadth
- `quality_of_life_index` — broadband, transit, WFH, higher-ed, health outcomes
- `risk_resilience_index` — FEMA NRI, flood/heat risk (blocked on source ingestion)
- `investment_score` — composite of all above (last to ship)

---

## Visual Library

**Location:** `visual_library/`

A reusable visual system combining chart specifications, shared R prep/render functions, data contract standards, benchmark defaults, and sample SQL/outputs.

**15 chart types implemented** (each has spec, question coverage doc, sample SQL, sample output, decisions log):
bar, line, scatter, choropleth, slopegraph, bump chart, heatmap table, age pyramid, hexbin, highlight context map, proportional symbol map, bivariate choropleth, correlation heatmap, strength strip, boxplot

**Key files:**
- `visual_library/README.md` — primary entry point and source-of-truth hierarchy
- `visual_library/visual_style_guide_and_standards.md` — canonical visual rules
- `visual_library/sample_library.md` — chart catalog and canonical question patterns
- `visual_library/agent.md` — chart build workflow for agents
- `visual_library/shared/` — shared `prep_*.R`, `render_*.R`, `standards.R`, `data_contracts.R`
- `visual_library/contracts/data_contract_dictionary.md` — shared contract vocabulary
- `visual_library/benchmark_defaults.md` — default benchmark sets by geography

**Tech:** R + ggplot2. All chart outputs are PNG. Charts accept a structured data contract from `prep_*.R` functions before rendering.

---

## Products

### 1. Retail Opportunity Finder (ROF)
**Status:** Flagship product, most mature. Has modular section architecture, integration flow, output contracts, and a published MVP payload.

**Location:** `notebooks/retail_opportunity_finder/`, `docs/rof-mvp/`

**Purpose:** Identify, score, zone, and shortlist retail opportunity areas and parcels by market.

**Sections:** 01–06 modular sections with SQL feature queries, shared runtime/config, validation summaries, and published output.

---

### 2. US Demographic and Economic Analytics Chatbot
**Status:** In design/early development. Spec complete. Being planned for migration to a standalone repo.

**Location:** `products/chatbot/`

**Purpose:** A constrained analytical copilot that answers natural language questions about US demographic and economic data.

**User workflow:**
1. User enters a question
2. System parses intent, metrics, geography, timeframe
3. Maps to approved semantic layer metadata
4. Generates SQL against Gold tables
5. Validates SQL
6. Executes query
7. Profiles result shape
8. Selects chart type
9. Renders chart via visual library
10. Returns: written answer + chart + table + SQL + metric definitions

**Tech stack:**
- Backend: Python + FastAPI
- Frontend: Streamlit (MVP)
- Data layer: DuckDB querying Gold schema
- LLM: Claude API (intent parsing, query planning, constrained SQL generation, chart selection, response writing)
- Visualization: R visual library (ggplot2)

**Design principles:** Reliability over openness, transparent analytics (SQL always visible), controlled SQL generation (grounded in metadata — no free-form LLM invention), visual consistency, iterative scope.

**MVP subject areas:** Population, income/earnings, housing/rent, labor market, education, migration

**MVP chart types:** Bar, line, scatter, choropleth, boxplot, histogram, heatmap table, highlight context map

**Chatbot docs:**
- `products/chatbot/README.md` — product overview
- `products/chatbot/us_demographic_economic_analytics_chatbot_spec.md` — full product spec
- `products/chatbot/MIGRATION.md` — guide for standing up as a standalone repo
- `products/chatbot/docs/` — architecture, semantic layer, frontend, visual library integration

---

### 3. Texas School District Analysis
**Status:** Secondary analysis track, partial. Two notebooks, one rendered output map.

**Location:** `notebooks/tx_school_districts/`

**Purpose:** School district scoring and reporting using ACS and ISD data. Has its own Gold table (`gold.tx_isd_metrics`).

---

## Shared Platform Code

**R functions:** `R/` — reusable analytics functions used across the pipeline
- `R/acs_ingest.R`, `R/acs_standardize_cols.R`, `R/acs_drop_moe.R` — ACS ingestion utilities
- `R/add_growth_cols.R`, `R/benchmark_summary.R` — analytics helpers
- `R/rebase_cbsa_from_counties.R` — CBSA rebasing logic
- `R/visual/` — shared chart prep/render functions (mirrors `visual_library/shared/`)

**Scripts:** `scripts/etl/` — named ETL workflow scripts (ingest, standardize, model, QA, publish)

**Config:** `config/project.yml` — project configuration including GEOID, year range, feature toggles

**Tests:** `scripts/testthat.R` and `tests/` — testthat-based automated checks; CI runs on push/PR to main via `.github/workflows/ci.yml`

---

## Data Dictionary

**Location:** `schemas/data_dictionary/`

The durable metadata layer for the warehouse. Covers:
- Table-level metadata: purpose, grain, keys, time coverage, geo coverage
- Column-level metadata: type, null %, distinct count, definitions
- Lineage: upstream sources, ETL scripts, write targets
- KPI definitions

**Structure:** Each Silver and Gold table has a YAML + Markdown pair (`<schema>__<table>.yml` and `.md`). Staging uses family-level contracts rather than one file per geography replica.

**Key governance docs:**
- `schemas/data_dictionary/docs/governance/coverage_checklist.md`
- `schemas/data_dictionary/docs/governance/data_quality_checklist.md`
- `schemas/data_dictionary/agent.md` — how agents should use and update the dictionary

---

## Semantic Layer (In Progress)

The chatbot requires a machine-readable semantic layer that the warehouse does not yet fully expose. Planned components:

- **Metric catalog** — name, definition, formula, valid grains, source table, caveats
- **Table catalog** — schema, grain, time field, geography fields, subject area
- **Join catalog** — approved join paths, keys, cardinality notes
- **Geography hierarchy catalog** — Tract → County → CBSA → State → Region relationships
- **Chart recommendation rules** — maps question type + result shape to allowed chart types
- **Example question library** — tagged NL questions, sample SQL, chart type, expected output

---

## Current Implementation Status

| Area | Status |
|---|---|
| Bronze/Staging ingestion | Working; staging docs being standardized to family-level contracts |
| Silver layer | Mostly complete; social infrastructure Silver still in progress; CAINC4 bug pending fix |
| Gold base marts | 9 tables complete as of April 2026 |
| Gold normalization supplements | Planned; not started |
| Gold composite scores | Design complete; blocked on base mart stability and weight approvals |
| Visual library | All 15 chart types structurally present; shared layer mature; some chart implementations still partial |
| ROF product | Working MVP; sections 01–03 most portable; 04–06 still transitional |
| Chatbot product | Spec and architecture complete; migration to standalone repo in progress |
| Texas school districts | Partial; secondary track |
| Semantic layer for chatbot | Not yet built |

---

## Cross-Repo Connection Points

If you are working in a downstream repo (e.g., the chatbot repo), the interfaces to this platform are:

| Interface | What It Is | Location in this repo |
|---|---|---|
| DuckDB Gold layer | Primary query target; `.duckdb` file or Parquet exports | `data/` or specified output path |
| Gold table specs | YAML + Markdown table contracts | `schemas/data_dictionary/layers/gold/` |
| Visual library | R-based chart functions; call `prep_*.R` then `render_*.R` | `visual_library/shared/` and `R/visual/` |
| Example question library | Tagged NL questions with SQL and chart types | `products/chatbot/data/` |
| Gold SQL definitions | Source SQL models for all Gold tables | `scripts/etl/gold/` |
| Config conventions | Geo level codes, field naming, grain standards | `DBDesign.md`, `schemas/data_dictionary/` |

---

## Key Conventions Quick Reference

- **Geo key fields:** `geo_level`, `geo_id`, `geo_name`
- **Time field:** `year` (default); `period` only for non-ACS BEA/BLS series
- **CBSA:** Derived from 2023 county membership; rebased from county data where direct CBSA values are unavailable
- **Silver pattern:** `<theme>_base` (ACS-aligned) + `<theme>_kpi` (business semantics)
- **Gold pattern:** Wide tables per domain; supplement tables for normalization; composite scores separate
- **RPP backfill order:** County → CBSA → State MARPP
- **Geo scope for ratios (e.g., rent-to-income):** Compute for all supported geographies
- **IRS migration:** Not in Gold v1; ACS mobility and nativity ship first
- **Zillow:** Supplement Gold table, not integrated into housing_core_wide v1
- **Language preference:** SQL first (DuckDB); R where SQL is awkward; Python only as last resort
