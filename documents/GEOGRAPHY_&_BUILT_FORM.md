# Geography & Built Form — README

This document describes the **purpose, data, functions, workflow, visuals, dependencies, and repo layout** for the *Geography & Built Form* section of the Metro Deep Dive, using the current Wilmington, NC example.

---

## 1) Purpose & Questions

**Goal:** Characterize the metro’s physical pattern and connectivity.

**Core questions**

* What are the key sub‑areas? Where is density concentrated?
* How is the region connected (major vs local roads)?
* Where do workers flow to/from (commute inflow/outflow)?

**Outputs**

* Tract population **density heatmap** (green → yellow → red, sqrt scale).
* **Roads overlays** (TIGER primary and county variants; filtered presets).
* **Commute flow bar chart** (inflow/outflow/internal from LEHD LODES).
* **Commute flow maps** (inflow origins / outflow destinations by county).

---

## 2) Data & Inputs

### 2.1 Environment variables (from `.Renviron`)

* `GOLD_XWALK` → folder containing crosswalks (CSV files).
* `SILVER_TRACT` → folder containing cleaned ACS tract tables.

### 2.2 Files used

* **Crosswalk:** `cbsa_county_crosswalk.csv`

  * Required columns: `cbsa_code`, `county_geoid` (5-digit)
  * *Note:* This crosswalk has **no year** in your current setup; we do not filter by year.
* **ACS Tract (Silver):** `acs_tract_nc_5_year.csv`

  * Columns used (renamed in-script):

    * `geoid`, `year`
    * `pop_total_e`   → `pop_total`
    * `income_med_e`  → `median_income`
    * `gross_rent_med_e` → `median_rent`
    * `total_housing_units_e` → `housing_units`
    * `in_labor_force_pop_e`  → `labor_force`
    * `rent_income_percent`   → `rent_income_ratio`

### 2.3 External programmatic sources

* **TIGER/Line (via `{tigris}`):** CBSA boundary, tracts, places, roads.
* **LEHD LODES (via `{lehdr}`):** Origin–Destination county-level flows.
* **OSM (`{osmdata}`):** *Optional* (we default to TIGER for reliability/perf).

### 2.4 CRS

* Analysis/plot equal-area: **EPSG:5070** (NAD83 / Conus Albers).
* Geographic (query/IO): **EPSG:4326**.

---

## 3) Workflow Overview

1. **Setup**: load utils, libraries, paths, parameters (`target_geoid`, `metro_name`, `cbsa_year_geo`, CRS constants).
2. **Helpers** (R functions):

   * CBSA/tract/place loaders (`get_cbsa_geom`, `get_cbsa_states`, `load_cbsa_tracts`, `load_places`).
   * Measurement utilities (`project_and_measure`, `geom_area_km2`, `geom_length_km`).
   * Grid & summarizers (`make_hex_grid`, `sum_length_by_zone`, `sum_area_by_zone`).
   * Class breaks (`make_breaks`).
3. **Load & clean data**: read crosswalk + ACS, standardize names, select/rename needed ACS columns.
4. **Geometries**: pull CBSA boundary, tracts in CBSA, and places that intersect CBSA; project to EPSG:5070.
5. **Join attributes**: merge ACS (current year) onto tract geometries; compute `aland_km2` and `density`.
6. **Roads**: fetch/classify **primary** and **county** roads, clip to CBSA, project, filter by presets; plot overlays.
7. **Commute flows**: fetch LODES for states covering CBSA counties; pick first year with data; summarize inflow/outflow/internal; plot bars + county-level maps with defensive scaling.

---

## 4) Functions (what/why/how)

### 4.1 Loaders

* `get_cbsa_geom(cbsa_id, year)` → CBSA polygon (TIGER), renamed to `cbsa_geoid`, `cbsa_name`.
* `get_cbsa_states(cbsa_id, crosswalk, year)` → derive state FIPS from CBSA’s counties.
* `load_cbsa_tracts(cbsa_id, crosswalk, year)` → union of state tracts, intersect with CBSA.
* `load_places(cbsa_id, crosswalk, year)` → places from relevant states, intersect with CBSA.

### 4.2 Measurements & grids

* `project_and_measure(g, epsg)` → safe projection step.
* `geom_area_km2(g_proj)`, `geom_length_km(g_proj)` → numeric area/length with units dropped.
* `make_hex_grid(boundary, cell_km)` → hex grid clipped to boundary (for future street/built‑up density work).
* `sum_length_by_zone()`, `sum_area_by_zone()` → zonal summaries (future metrics).

### 4.3 Roads (TIGER-first)

* `classify_tiger_roads(roads_sf, layer = c("county","primary"))` → stable human-friendly classes from `MTFCC` or `RTTYP`.
* `get_primary_roads_cbsa(cbsa_sf)` → national primary roads clipped to CBSA; classified as interstate/us/state…
* `get_county_roads_cbsa(cbsa_id, crosswalk_df, cbsa_sf)` → per-county roads fetched and clipped; classified (primary/secondary/local/ramp/etc.).
* `plot_roads_layer(layer_sf, title)` → overlays selected road layer on tract density with styled linetypes/widths.

### 4.4 Commute flows (LEHD LODES)

* `co5_to_postals(co5)` / `fips_to_postal()` → FIPS ↔ state postal helpers.
* `fetch_lodes_cbsa(cbsa_id, crosswalk_df, years_try)` → pull OD for all required states; first year with data wins.
* `summarize_commute_flows(lodes, co5, metro_title, year_used)` → inflow/outflow/internal totals.
* `plot_commute_bars(commute_summary, title)` → bar chart (short-scale labels).
* `plot_commute_map(lodes, co5, cbsa_sf, type)` → map of origins (inflow) or destinations (outflow) by **county**; defensive scaling and green→yellow→red palette.
* `build_commute_flows(...)` → one-step wrapper returning `list(year_used, co5, states, summary, title, raw)`.
* `lookup_county_names()`, `build_top_commute_tables()`, `plot_top_commute_bars()`, `combine_side_by_side()` → optional **Top N** inflow/outflow visuals.

---

## 5) Transformations (key derivations)

* **Tract metrics**: `aland_km2 = ALAND / 1e6`; `density = pop_total / aland_km2` (guard `aland_km2 > 0`).
* **Roads**: clip to CBSA, project to EPSG:5070, classify by hierarchy (`MTFCC`/`RTTYP`).
* **LODES**: aggregate OD at county level relative to CBSA county set:

  * **Inflow** = live outside (home county not in CBSA), work inside (work county in CBSA).
  * **Outflow** = live inside, work outside.
  * **Internal** = live & work inside.

---

## 6) Visuals (current conventions)

* **Palette:** green `#1a9850` → yellow `#fee08b` → red `#d73027` (sqrt transform where appropriate).
* **Themes:** `md_theme()` minimal map framing; `white_bg()` for exporter-friendly backgrounds.
* **Road overlays presets:**

  * `arterials_only` = `primary`,`secondary` (cleanest overview)
  * `arterials_plus_ramps` = adds `ramp`
  * `arterials_plus_local` = adds `local` (busiest)
* **Commute maps:** defensive `limits` + `oob = squish` + `label_comma()` to avoid scale errors when sparse.

---

## 7) Dependencies

Core CRAN (or r-universe) packages used:

* `sf`, `dplyr`, `readr`, `stringr`, `tidyr`, `purrr`, `ggplot2`, `units`, `classInt`, `scales`, `glue`, `janitor`
* Spatial fetchers: `tigris` (TIGER/Line), `lehdr` (LODES); `osmdata` is optional.

**Recommended options:**

```r
options(tigris_class = "sf")   # ensure sf objects from tigris
```

**Mac note (optional OSM):** If `osmdata` install fails from CRAN, try rOpenSci’s r-universe binary:

```r
options(repos = c(ropensci = "https://ropensci.r-universe.dev", CRAN = "https://cloud.r-project.org"))
install.packages("osmdata")
```

---

## 8) Troubleshooting (common)

* **`st_transform` no method for data.frame** → ensure the object is `sf` (don’t lose geometry by `bind_rows` on non-sf lists; use `do.call(rbind, ...)` or `dplyr::bind_rows` on sf only).
* **Crosswalk column names** → this workflow expects `cbsa_code` and `county_geoid`. If your file has `county_fips`, rename to 5-digit `county_geoid`.
* **Scales error about `label_number_si()`** → replaced with `label_number(scale_cut = cut_short_scale())`.
* **Sparse LODES year** → `fetch_lodes_cbsa` tries `c(2023, 2022, 2021, 2020, 2019)` and picks the first with rows.
* **All-zero commute maps** → function switches off sqrt transform and adds a subtitle to indicate zero map.

---

## 9) Suggested Repo Structure

```
project/
├─ notebooks/
│  └─ geography_built_form_wilmington.Rmd        # this analysis notebook (user-facing)
├─ R/                                            # modular R functions
│  ├─ cbsa_loaders.R           # get_cbsa_geom, get_cbsa_states, load_cbsa_tracts, load_places
│  ├─ metrics_geometry.R       # project_and_measure, geom_area_km2, geom_length_km, grids, zonal summaries
│  ├─ roads_tiger.R            # classify_tiger_roads, get_primary_roads_cbsa, get_county_roads_cbsa
│  ├─ plots_density_roads.R    # md_theme, white_bg, plot_density_map, plot_roads_layer
│  ├─ lodes_commute.R          # co5_to_postals, fetch_lodes_cbsa, summarize_commute_flows
│  ├─ plots_commute.R          # plot_commute_bars, plot_commute_map, top-N helpers
│  └─ utils.R                  # get_env_path, general helpers used across notebooks
├─ scripts/
│  ├─ build_geography_artifacts.R    # batch runner to generate PNGs for a CBSA list
│  └─ fetch_lodes_cache.R            # (optional) prefetch/cache LODES
├─ data/
│  ├─ bronze/...
│  ├─ silver/
│  │  └─ tract/acs_tract_nc_5_year.csv
│  └─ gold/
│     └─ crosswalk/cbsa_county_crosswalk.csv
├─ outputs/
│  ├─ maps/
│  └─ tables/
└─ .Renviron                      # paths: GOLD_XWALK, SILVER_TRACT
```

**Modularization plan**

* Extract the functions in section 4 into the `R/` files above; keep the notebook focused on parameters, run order, and final figures.
* Scripts in `scripts/` can iterate over multiple CBSAs and write artifacts to `outputs/`.

---

## 10) Repro Steps (Quick Start)

1. Set `.Renviron` paths: `GOLD_XWALK`, `SILVER_TRACT`.
2. Open `notebooks/geography_built_form_wilmington.Rmd`.
3. Knit or run chunks in order:

   * Setup → Load & Clean Data → Ingest Geo → Prepare Data.
   * Density plot → Roads (primary, county presets) → Commute flows (build + bars + maps) → Optional Top‑N.
4. (Optional) Save artifacts with `ggsave(...)` in the “Test Roads Plots” section.

---

## 11) Future Improvements

* **Transit overlay**: GTFS or MPO shapefiles for routes/stops/frequencies.
* **OSM fallback/merge**: optional higher-resolution local streets; add `source = c("tiger","osm","auto")` flags.
* **Catchment-aware LODES**: include adjacent/buffered states (e.g., `states_mode = c("cbsa","adjacent","buffer")`).
* **Hex-based metrics**: street length density, built-up ratio, land use mix; small multiples across the metro.
* **Block-level density**: optional deeper cut where ACS block data is available.
* **Caching**: memoize TIGER/LODES pulls per CBSA-year.
* **Palette helpers**: centralize Deep Dive theming and color scales in `R/theme_deepdive.R`.

---

## 12) Glossary

* **CBSA**: Core-Based Statistical Area.
* **LODES**: LEHD Origin–Destination Employment Statistics.
* **MTFCC/RTTYP**: TIGER road classification codes.
* **ALAND**: Land area (m²) from TIGER.
* **Hex grid (km)**: Honeycomb zoning for uniform area-based summaries.

---

*Last updated:* this README reflects the code currently in the notebook and canvas, including the green→yellow→red color scheme and the robust LODES mapping fixes.
