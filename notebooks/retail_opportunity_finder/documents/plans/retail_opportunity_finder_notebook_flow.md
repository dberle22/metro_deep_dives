# Retail Opportunity Finder — Notebook Flow

This document outlines the recommended **Quarto notebook flow** for the Retail Opportunity Finder (V1) workflow: **Funnel → Rank → Cluster → Shortlist**.

---

## Part A — Technical Foundation

### 1. Setup and approach

**Narrative**
- One paragraph on what this report does (funnel → rank → cluster → shortlist).
- One paragraph on why these KPIs (growth + capacity + “not priced-in”).

**Technical**
- Load packages (`duckdb`, `DBI`, `sf`, `dplyr`, `ggplot2`, `tmap`/`leaflet`, `glue`, `units`).
- Set globals (themes, map CRS, caching).
- Connect to DuckDB; set schema names.
- Load required tables/views.

**Outputs**
- A “run metadata” block (run date, data vintages, git hash if available).

---

### 1.1 Data sources and table inventory (short, but explicit)

**Inputs**
- **ACS** (2019 5yr + 2024 5yr): tract-level
- **BPS**: county-year → tract via county
- **TIGER**: tract polygons + land area
- **Parcel polygons (JAX)**: land-use codes + geometry

**QA (quick)**
- A compact table: row counts + missingness for key fields (by table).

---

### 1.2 Reusable helper functions (optional, minimal)

Keep these minimal and focused:
- `calc_percentile_rank(x)`
- `zscore(x)`
- `make_why_tags(row)`
- `map_choropleth(sf, value_col)`
- `map_overlay(sf_polys, sf_points_or_polys)`

---

## Part B — Analytics Narrative

## 2. Target market overview

**Goal:** “Why this metro, at a glance?”

### 2.1 Metro KPI snapshot

**Visuals**
- KPI tiles: current population, 5y growth, median rent, median home value, mean commute, permits/units per 1k (county-weighted or simple summary).
- Small peer table: Jacksonville vs peer metros (e.g., Wilmington, Savannah, Raleigh, Greenville) and optionally vs US.

---

#### Section 2.1 Visual A — Metro KPI tiles

**Goal:** “Jacksonville at a glance” with ~5–6 numbers.

**Inputs**
A metro-level snapshot table (1 row per geo and vintage) with:
- `population`
- `pop_growth_pct_5yr` (2019→2024)
- `median_gross_rent`
- `median_home_value`
- `mean_commute_minutes` (optional)
- `units_per_1k_3yr` (BPS est units per 1k; 3-year rolling avg)

**Transform**
1. Filter to `target_metro` and `acs_vintage == "2024_5yr"`
2. Select KPIs
3. Format for display (commas, %, $, 1 decimal where relevant)

**Output**
A 2×3 (or 1×6) tile grid:
- Population (2024 5yr)
- 5y Pop growth
- Units per 1k (3y avg)
- Median rent
- Median home value
- Mean commute (optional)

**R build approach**
- `gt` (cleanest for tiles) or `patchwork` + `ggplot2` (DIY)
- Helper: `format_kpi(value, type)`

---

#### Section 2.1 Visual B — Peer ranking table (small)

**Goal:** Put Jacksonville in context vs initial peer set (and optionally US).

**Inputs**
Metro-level table (one row per metro) with the same KPI columns as the tiles.

**Transform**
1. Filter to peer metro list (+ Jacksonville + optional US)
2. Compute ranks for each KPI among peers:
   - Higher is better: `pop_growth_pct_5yr`, `units_per_1k_3yr`
   - Lower is better: price proxy percentile or density (optional; keep simple)

**Output**
Compact table columns:
- `metro_name`
- `pop_growth_pct_5yr_rank`
- `units_per_1k_3yr_rank`
- `median_rent_rank`
- `median_home_value_rank`
- `density_rank` (optional)

**R build approach**
- `dplyr::min_rank(desc(x))` (and `min_rank(x)` for lower-is-better)
- `gt` formatting

---

#### Section 2.1 Visual C — Benchmark comparison table (JAX vs Region vs US)

**Goal:** Show **raw values** (not ranks) for:
- Jacksonville
- Region benchmark (e.g., South Atlantic)
- United States

**Inputs**
Benchmark KPI table with:
- `geo_level` (metro/region/us)
- `geo_name`
- `acs_vintage`
- KPI columns: `population`, `pop_growth_pct_5yr`, `units_per_1k_3yr`, `median_gross_rent`, `median_home_value`
- Optional: `pop_density`, `commute_intensity` or `mean_commute_minutes` + `pct_wfh`

**Transform**
1. Filter to `acs_vintage == "2024_5yr"` (and ensure growth metric joins appropriately)
2. Filter to the 3 benchmark rows
3. Select raw KPIs and format
4. Optional: add `JAX_vs_US` and `JAX_vs_Region` (ratio or delta)

**R build approach**
- `dplyr` for filtering + derived comparisons
- `gt` formatting (`fmt_number()`, `fmt_percent()`, `fmt_currency()`, `tab_spanner()`)

---

### 2.2 Growth and capacity context (keep it tight)

**Visuals (pick 2–3)**
- Line chart: population trend (metro vs US vs region)
- Bar chart: 5-year growth comparison vs peer metros
- Dot plot: rankings of key metrics (growth, density, rent/value, permits per 1k)

**Narrative**
- 5–8 bullets: what stands out (e.g., growth strong, permits strong, price moderate)
- Tip: treat as “weather report” before the hike (high signal, low detail).

---

#### Section 2.2 Visual D — Population trend line (metro vs US vs region)

**Goal:** “Is this metro in a growth regime?”

**Inputs**
Time series table with:
- `geo` (Jacksonville, Region, US)
- `year` or `acs_vintage`
- `population`

**Transform (two options)**
- Absolute population (size context), or
- Indexed to 100 at baseline year (recommended):
  - `pop_index = 100 * population / population[baseline_year]`

**Output**
Line chart with 3 lines:
- Jacksonville
- Region benchmark
- US benchmark

**R build approach**
- `ggplot2::geom_line()`
- Consistent vintage labels (e.g., “2014 5yr … 2024 5yr”)

---

#### Section 2.2 Visual E — All-metro distribution boxplots with Jacksonville highlighted

**Goal:** Show where Jacksonville sits vs **all U.S. metros** across key KPIs.

**Inputs**
Metro-level KPI table (one row per CBSA) for the chosen vintage/growth window:
- `cbsa_geoid`, `metro_name`
- `pop_growth_pct_5yr` (ACS 2019 5yr → 2024 5yr)
- `units_per_1k_3yr` (BPS est units per 1k; 3y rolling avg)
- `pop_density` (explicit metro definition recommended)
- `median_gross_rent` (ACS 2024 5yr)
- `median_home_value` (ACS 2024 5yr)
- Optional: `commute_intensity`

**Jacksonville identifiers**
- `jax_cbsa_geoid` (or exact `metro_name`) to flag highlight.

**Notes on “metro density”**
Preferred:
- `metro_density = total_population / total_land_area`
Acceptable:
- population-weighted mean of tract densities

**Transform**
1. Filter to consistent universe (handle missingness per metric)
2. Pivot long: `metric`, `value`, `metro_name`, `cbsa_geoid`
3. Flag JAX: `is_jax = cbsa_geoid == jax_cbsa_geoid`
4. Add metric labels + ordering (Growth → Supply → Density → Rent → Value)
5. Optional: winsorize tails (1st/99th) if needed; annotate caption if used

**Output**
Faceted distribution chart:
- Boxplot for all metros per metric
- Jacksonville overlay as a point (recommended), optional label “JAX”
- `facet_wrap(~ metric_label, scales = "free_y")`
- `nrow = 1` for 4–5 metrics, else `nrow = 2`

**R build approach**
- `tidyr::pivot_longer()`
- `ggplot2::geom_boxplot()` + `geom_point(data = subset(is_jax), ...)`
- Optional faint jitter behind the boxplot:
  - `geom_jitter(alpha = 0.15, width = 0.1)`

---

## 3. Eligibility and scoring model (tract screening)

**Goal:** Make the model transparent and testable.

### 3.1 KPI definitions (brief recap)
- Pop growth 5y (2019→2024 ACS 5yr)
- Headroom via density
- Housing supply via BPS estimated units per 1k (3y rolling avg)
- Price proxy percentile = average of rent and value percentiles; gate below 70th
- Commute intensity Option B

---

### 3.2 Gate walkthrough (the funnel)

**Visuals**
- Funnel table: count of tracts remaining after each gate
- Histogram: price proxy percentile with vertical line at 0.70
- Histogram: pop growth distribution with median marker
- Map: eligible tracts (binary)

**Narrative**
- 1–2 paragraphs: what the gates protect against (false positives).

---

### 3.3 Tract ranking model

**Purpose:** Among eligible tracts, produce a single score reflecting the thesis and easy to explain.

#### 3.3.1 Scoring formula (one box)
Within-metro z-scores:
- `z_growth` = z-score(5y pop growth)
- `z_units` = z-score(units per 1k, 3y avg)
- `z_headroom` = z-score(-density) or `-z(density)`
- `z_price` = z-score(-price proxy) (percentile or level, depending)
- `z_commute` = z-score(commute intensity Option B)

V1 weights (locked):
- 0.40 growth
- 0.25 units
- 0.20 headroom
- 0.10 price (guardrail)
- 0.05 commute (supporting)

Score:
```
tract_score =
  0.40*z_growth +
  0.25*z_units +
  0.20*z_headroom +
  0.10*z_price +
  0.05*z_commute
```

Add one sentence: “We standardize within metro so the score reflects relative opportunity, not absolute levels.”

---

#### 3.3.2 Score diagnostics (trust checks)

**Visuals**
- Histogram of `tract_score` (eligible tracts only)
- Scatter: pop growth vs density with top tracts highlighted
- Optional: correlation heatmap of score components (redundancy check)

---

#### 3.3.3 Top tracts + “why tags”

**Table**
Top 25 tracts with:
- `rank`, `tract_score`
- raw KPIs + percentiles
- optional component contributions (powerful):
  - `contrib_growth = 0.40*z_growth`, etc.
- auto “why tags”:
  - High growth
  - High housing pipeline
  - Low density headroom
  - Moderate price pressure
  - High commute exposure

---

#### 3.3.4 Sensitivity check (small but valuable)

**Concept**
- “If we change weights modestly, do top zones change?”

**Visual**
- Overlap metric: % of top 20 tracts that remain top 20 under an alternative weight set

(Keep as hidden/optional chunk initially.)

---

### 3.4 Initial target tracts (top N) + map

**Visuals**
- Dot plot: top N tract scores
- Table: top 25 tracts with score + rank + core KPIs + why tags
- Optional: scatter pop growth vs density (highlight top tracts)

---

## 4. Zone creation (tract → contiguous clusters)

**Goal:** Transform a ranked list into usable “submarkets.”

### 4.1 Zone method (brief)
- Start with top N tracts (default 50)
- Identify touching tracts (adjacency)
- Dissolve connected components into zones
- Adjust N/threshold to land in ~3–8 zones

### 4.2 Zone maps and summaries

**Visuals**
- Map: zones with labels (Zone A, B, C…) and outline
- Table: zone summaries:
  - tracts count, total pop, 5y pop growth (weighted), density (median),
    units per 1k, price proxy percentile
- Optional: small multiples maps for 2 drivers (growth, headroom) by zone

**Narrative**
- 3–6 bullets describing each zone (e.g., “northwest growth corridor”).

---

## 5. Retail corridor overlay and property shortlist (parcel layer)

**Goal:** Connect “where” to “what.”

### 5.1 Retail intensity context (existing corridor signal)

Using JAX parcels + land-use codes:
- `retail_parcel_count` by tract
- `retail_area_density = retail_area / tract_land_area_sqmi`

**Visuals**
- Choropleth: retail parcel count
- Choropleth: retail area density
- Overlay map: zones + retail parcels (or tract-level intensity)

**Narrative**
- Identify “established corridors” vs “adjacent opportunity.”

---

### 5.2 Shortlist: parcels inside target zones

**Visuals**
- Map: shortlisted parcel polygons over zones
- Table: top parcels (top 25–50) with:
  - parcel id, land use, area, assessed value,
    last sale date/price (if available),
    zone, zone score, nearby retail intensity (optional)
- Optional scatter: assessed $/sf vs zone score (if sqft available)

---

### 5.3 Micro deep dive (optional, 1–2 pages max)

Pick 1–2 zones and show:
- zoomed map
- top 10 parcels
- quick “corridor description” bullets

---

## 6. Conclusion and appendix

### 6.1 Conclusion
- 3–5 bullets: top zones + why
- 3–5 bullets: next actions (site visits, comps, zoning checks, tenant mix research)

### 6.2 Appendix
- Definitions (all KPIs, percentile + z-score rules)
- Assumptions (e.g., BPS midpoint expansion + cap rules)
- Data caveats (“blind spots”)
- QA checks summary (missingness, outliers, geometry validity)
