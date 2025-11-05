# Metro Deep Dive — Overview Snapshot (README)

This README explains the end‑to‑end workflow for the **Overview Snapshot** section using Wilmington, NC (CBSA **48900**) as a working example. It covers data sources, our constant‑geometry strategy, KPI math, benchmark logic, chart styles, export conventions, and how to modularize the current notebook into reusable scripts. It also lists the order of operations to run and how this will scale to all metros and future sections.

---

## 1) Goals & Deliverables

**Goal:** Produce a concise, comparable metro snapshot with growth context and on‑brand visuals, backed by constant geometry (2023 county definitions) to avoid ACS boundary discontinuities.

**Artifacts (saved in `artifacts/`):**

* Overview KPI table (PNG/HTML; optional XLSX)
* Trend charts: Population and Real GDP (PNG)
* Growth comparison bars vs. benchmarks (PNG)
* Radar chart (Z‑score indexed small multiples, PNG)
* Regional and state choropleths with target highlight (PNG)
* Rank leaderboards (state/SE/US) (PNGs) + tidy CSVs

---

## 2) Data & Layers

**Inputs (Silver/Gold):**

* **ACS** 5‑year CBSA and County tables (population; tract/place available for later sections)
* **BEA** CBSA & County GDP (chained 2017$, *in thousands*)
* **BEA** CBSA & County personal income
* **RPP** (Regional Price Parities) for real income adjustments
* **Crosswalks (Gold):** `cbsa_county_crosswalk`, CBSA metadata (primary state, region, division), state↔division

**Constant geometry:** We **rebase metro metrics from counties** using **2023 county membership** for *all years*. This prevents false jumps from boundary changes and ensures apples‑to‑apples growth.

Environment variables (preferred) in project `.Renviron`:

```
SILVER_CBSA=.../data/silver/cbsa
SILVER_COUNTY=.../data/silver/county
GOLD_XWALK=.../data/gold/crosswalk
GOLD_CBSA=.../data/gold/cbsa
```

Helper to read: `get_env_path(key)`; optional `require_env(keys)` warns on missing keys.

---

## 3) KPI Definitions & Naming

We standardized the metric names used by the notebook and downstream scripts:

**Level variables**

* `population` — ACS 5‑year population
* `gdp_thousands` — BEA real GDP (chained 2017$), **thousands**
* `inc_total` — BEA personal income (nominal or deflated as configured)
* `inc_pc` — income per capita (optionally RPP‑adjusted)
* `gdp_pc` — GDP per capita

**Growth (Δ over 5y)**

* `pop_chg_5y`, `gdp_chg_5y`, `gdp_per_cap_chg_5y`, `inc_chg_5y`, `inc_per_cap_chg_5y`

**CAGR (5y)**

* `pop_cagr_5y`, `gdp_cagr_5y`, `gdp_per_cap_cagr_5y`, `inc_cagr_5y`, `inc_per_cap_cagr_5y`

> **Formulas:**
>
> * **% change (h years):** (chg_h = x_t/x_{t-h} - 1)
> * **CAGR (h years):** (cagr_h = (x_t/x_{t-h})^{1/h} - 1)

We prefer **per‑capita** KPIs for cross‑metro comparisons and keep totals for scale context.

---

## 4) Custom Functions

**`add_growth_cols(df, id_cols, year_col="YEAR", value_col, horizons=c(1,3,5,10), prefix="")`**
Adds `% change` and `CAGR` columns for the specified `value_col` across requested horizons. Expect columns `id_cols`, `YEAR`, and `value_col`. Used upstream to compute growth consistently.

**`rebase_cbsa_from_counties(df, weight_col=NULL)`**
Aggregates county‑level series to CBSA level for *each year* using constant 2023 membership. Sums additive metrics (e.g., population, GDP totals) and computes **weighted means** for rate/ratio metrics if `weight_col` is provided.

**`bench_summary(df, method=c("metro_mean","pop_weighted"))`**
Collapses a set of metros into a single benchmark row. By default, simple metro mean; with `pop_weighted`, uses `population` as weights.

**`z_to_index(x, mu, sd)`**
Converts KPI values to a **0–100 index** using a T‑score style mapping `50 + 10*z`, clamped to [0,100]. Shared scale across radar panels.

**`get_env_path(key)` / `require_env(keys)`**
Helpers for `.Renviron`‑based configuration.

---

## 5) Benchmarks

**Scopes**

* **NC Metros Avg:** same primary state as target
* **SE Metros Avg:** divisions = South Atlantic, East South Central, West South Central
* **US Metros Avg:** all US metros (exclude PR)

**Methods**

* `metro_mean` (default) — simple average across metros
* `pop_weighted` — weights by metro population

> The notebook builds three `bm_*` frames (NC/SE/US) via `bench_summary()`.

---

## 6) Visual Style & Conventions

* **Palettes:** `viridis` (discrete for ranks/quintiles, continuous for highlights)
* **Themes:** `theme_minimal()` baseline, legend bottom when comparing entities
* **Axes:** Start y at 0 for level trends; years as integers (no mid‑year ticks)
* **Projection:** EPSG **5070** (CONUS Albers) for maps; transform states & CBSAs before plotting
* **Target Highlight:** double outline (black + viridis yellow) + bold label via `ggrepel`
* **Quintiles:** regional bins are reused for the **state map** to keep scales comparable
* **Radar:** 2×2 small multiples, unified 0–100 index, shared labels (0,20,…,100)

---

## 7) Execution Order (Notebook)

1. **Parameters & Paths** — set `cbsa_geoid`, `analysis_years`, benchmark divisions; load `.Renviron`.
2. **Create Base Metrics Tables** — load `cbsa_const_latest` (already built from counties) → `cbsa_metrics`.
3. **Target vs Benchmarks** — slice `wilm_row` + define `bench_nc`, `bench_se`, `bench_us`.
4. **Benchmarks** — compute `bm_nc`, `bm_se`, `bm_us` via `bench_summary()`.
5. **Overview Table** — human‑readable KPI table (`gt`) + export.
6. **Trends** — population & GDP line charts (y starts at 0) + export.
7. **Growth Bars** — grouped bars for 5‑year % change vs benchmarks + export.
8. **Radar** — Z‑indexed small multiples (Wilmington, NC, SE, US) + export.
9. **Maps** — SE/South‑Central and Primary‑State quintile maps; target highlighted + export.
10. **Ranks** — state/SE/US leaderboards + CSVs and PNGs.

> Each step renders artifacts to `artifacts/` with consistent naming including `{cbsa_geoid}` and `{year}`.

---

## 8) Modularization Plan (from Notebook → R Scripts)

**R/ directory**

* `R/paths.R` — `.Renviron` helpers (`get_env_path`, `require_env`) + `ARTIFACTS_DIR()` helper
* `R/rebase_from_counties.R` — `rebase_cbsa_from_counties()` + county→CBSA aggregations
* `R/growth_helpers.R` — `add_growth_cols()`; safe joins; time‑window slicers
* `R/benchmarks.R` — `bench_summary()` + scope builders (state/se/us)
* `R/viz_theme.R` — ggplot theme, palettes, labelers (percent, short‑scale numbers)
* `R/plots_overview.R` — `plot_pop_gdp_trend()`, `plot_growth_bars()`
* `R/plot_radar.R` — Z‑score index build + small‑multiples radar
* `R/map_quintiles.R` — CBSA+states geometry, regional quintile bins, target highlight
* `R/tables_overview.R` — gt overview table + leaderboard exporters

**Scripts (bin/ or scripts/)**

* `scripts/build_cbsa_from_counties.R` — produce `cbsa_const_long` & `cbsa_const_latest`
* `scripts/overview_snapshot.R` — orchestrates steps 2–10 for a given `cbsa_geoid`
* `scripts/export_all_metros.R` — iterate all CBSAs (or by state/region) to batch‑render artifacts

**Notebooks (notebooks/)**

* `notebooks/overview_snapshot.Rmd` — analyst‑friendly narrative; calls functions above
* Future: `notebooks/geography_built_form.Rmd` (density, transport, commutes), `notebooks/affordability.Rmd`

---

## 9) QA & Troubleshooting

* **Wrong table lengths** (e.g., `Wilmington` vector length > 1): ensure `wilm_row` is a **single row** filtered by `cbsa_geoid`; `distinct()` if needed.
* **Parse warnings** on BEA/ACS CSVs: run `vroom::problems()`; set explicit types for `year`/`geoid`.
* **`label_number_si()` defunct:** use `label_number(scale_cut = cut_short_scale())`.
* **`st_point_on_surface` lon/lat warning:** compute labels after projecting to EPSG 5070 (as in notebook).
* **GDP units:** BEA chained dollars are in **thousands**; convert to millions for plotting.
* **Benchmark weights:** switch to `pop_weighted` if metro sizes should influence the average.

---

## 10) How This Scales (All Metros)

1. Build/refresh `cbsa_const_long` and `cbsa_const_latest` from county sources (2023 membership).
2. Run `scripts/overview_snapshot.R --cbsa 48900` (CLI arg) to render Wilmington artifacts.
3. Batch over a list of CBSAs (state or national) to produce a complete library of overview assets.

---

## 11) Roadmap — Next Sections

* **Geography & Built Form**

  * **Density heatmap** (tracts/blocks), **transport overlay** (TIGER + OSM), **commute flows** (LEHD), **sub‑area highlights**.
  * Stubs: `map_density.R`, `map_transport.R`, `plot_commute_flows.R`.
* **Affordability**

  * Housing costs (ACS/ACS microdata or Zillow/ACS proxies), income distribution (RPP‑adjusted), H+T composite.
  * Add `tables_affordability.R`, `plot_affordability.R`, `map_rent_to_income.R`.

---

## 12) Contribution Workflow (Git/Codex)

* Branch per feature (`feature/overview-radar-z`), PR to `main` with linked artifacts
* Keep **data paths out of Git**; rely on `.Renviron`
* Scripts idempotent; notebooks remain thin wrappers calling functions in `R/`
* Use `renv` or `pak` lockfile to pin packages for reproducibility

---

## 13) Glossary (Selected Columns)

* `cbsa_geoid` — CBSA FIPS code (string)
* `primary_state`, `division`, `region` — from metadata
* `population`, `gdp_thousands`, `gdp_pc`, `inc_total`, `inc_pc` — level metrics
* `*_chg_5y`, `*_cagr_5y` — growth metrics (5‑year window)

---

**Contact/Notes**
This README reflects the latest notebook logic and naming conventions. When refactoring, update this document alongside function signatures to keep analysts and automation in sync.
