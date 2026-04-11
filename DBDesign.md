*Database Design*

To build out a scalable analytics framework we need a durable medallion architecture:

- Bronze: raw extracts and source-of-record artifacts
- Staging: source-shaped landed tables used for reproducible transforms
- Silver: standardized, analysis-ready wide tables with consistent geo/time keys
- Gold: curated cross-domain marts and decision-ready KPIs

This document now serves two purposes:

- architectural reference
- concrete implementation backlog for closing the current Stage, Silver, and Gold gaps

*Architecture Summary*

*Bronze*

This is the raw data layer. We store CSVs exported from websites, downloaded source files, and raw API outputs here. The goal is reproducibility and source preservation.

*Staging*

This layer stores landed source-shaped tables. For ACS and similar sources, staging tables are often repeated across geographies with the same column concepts and slightly different grains. The main goal here is clean ingestion, stable naming, and reproducible landing contracts.

*Silver*

This layer contains standardized and lightly transformed tables. We normalize keys, unify geography conventions, compute straightforward KPI fields, and keep most subject-area tables in a wide format for exploration and easier Gold joins.

*Gold*

This layer contains curated, analysis-facing marts and derived KPIs. Gold should join across Silver domains, compute growth and semantic metrics, and eventually support normalized comparisons and composite scores.

*Granularities*

- US
- Region
- Division
- State
- CBSA
- County
- Census Place
- Census Tract
- ZCTA

CBSA is derived using 2023 Census county membership and county rebasing where needed.

*Current Direction*

- Keep Staging documentation lightweight and source/theme based rather than writing one document per geography replica table.
- Continue using Silver as the main standardized contract layer.
- Build Gold in SQL first wherever practical.
- Fall back to R only where existing R workflows are materially cleaner or where procedural reshaping is awkward in SQL.
- Use Python only as a last resort.
- Mark unresolved business-rule areas before implementation rather than hard-coding assumptions into Gold.

*Implementation Backlog*

*Do Now*

1. Staging documentation model
   - Replace the implicit expectation of one dictionary per staging table with source/theme-level contracts.
   - Keep one doc per source/theme family, for example ACS Age, ACS Income, BEA CAGDP2, HUD FMR.
   - Add compact geography coverage matrices inside those docs so users can see which geographies are materialized without needing separate files for each table.
   - Update staging checklist conventions so geography-replica tables are tracked as covered by family documentation rather than as missing standalone docs.

2. Silver social infrastructure
   - Create `silver.social_infra_base`.
   - Create `silver.social_infra_kpi`.
   - Use the existing `staging.acs_social_infra_*` tables as the source.
   - Match the established ACS Silver pattern used by age, income, labor, migration, housing, race, education, and transport.
   - Include CBSA rebasing from county data where appropriate.
   - Add these tables to the data dictionary and silver checklist.

3. Silver BEA bug fix
   - Fix the CAINC4 materialization bug so the CAINC4 transform writes:
     - `silver.bea_regional_cainc4_long`
     - `silver.bea_regional_cainc4_wide`
   - Verify that no downstream references assume the incorrect `cainc1` write targets.
   - Reconcile checklist and dictionary coverage after the fix.

4. Silver documentation alignment
   - Add any implemented-but-undocumented Silver helper/reference tables to the data dictionary if they are intended to remain part of the warehouse contract.
   - At minimum, confirm whether `silver.acs_variable_dictionary` should be promoted into the documented contract.

*SQL First*

Status: Completed on April 10, 2026.

These Gold tables have now been implemented in DuckDB SQL:

- `gold.housing_core_wide`
- `gold.migration_wide`
- `gold.transport_built_form_wide`
- `gold.affordability_wide`

These Gold tables should be attempted in DuckDB SQL first.

1. `gold.housing_core_wide`
   - Inputs:
     - `silver.housing_kpi`
     - `silver.income_kpi`
     - `silver.hud_fmr_wide`
     - `silver.hud_rent50_wide`
     - `silver.bps_wide`
     - optional later: Zillow Silver or staging-backed housing market series
   - Candidate outputs:
     - vacancy and tenure metrics
     - median rent and median home value
     - rent burden metrics
     - rent-to-income
     - value-to-income
     - FMR gap
     - permit intensity metrics
   - Notes:
     - start with a clean base mart before adding composite affordability or overheating scores

2. `gold.migration_wide`
   - Inputs:
     - `silver.migration_kpi`
     - Silver IRS migration outputs if available and validated
   - Candidate outputs:
     - ACS mobility shares
     - nativity shares
     - IRS inflow, outflow, net migration
     - migration churn
     - net migration rate
   - Notes:
     - ship an ACS-only version first if IRS rollups are not fully validated

3. `gold.transport_built_form_wide`
   - Inputs:
     - `silver.transport_kpi`
     - crosswalks and tract-level supporting data where needed
   - Candidate outputs:
     - drive-alone share
     - transit share
     - work-from-home share
     - households with no vehicle
     - mean travel time
     - built form metrics only where the denominator and geometry workflow are trusted

4. `gold.affordability_wide`
   - Inputs:
     - `gold.housing_core_wide`
     - `gold.economics_income_wide`
     - possibly transport and migration context later
   - Candidate outputs:
     - affordability inputs consolidated into one mart
     - normalized affordability fields if we choose to store them separately from composite scores

*Do After Base Gold Marts*

These are important, but they should come after the base marts above are stable and reviewed.

1. `gold.quality_of_life_wide`
   - Build only once source scope is finalized.

2. `gold.risk_resilience_wide`
   - Build only once source scope is finalized.

3. `gold.market_scores_wide`
   - Add normalized metrics:
     - z-scores
     - percentiles
     - min-max scaling
     - group-relative ranks
   - Add composite scores only after weights and included metrics are approved.

*Needs User Follow-Up*

These are the design choices that should be confirmed before implementation or before finalizing Gold logic.

1. Housing affordability scope
   - Should `rent_to_income` and `value_to_income` be computed for all supported geographies, or only for the core comparison geographies such as county, CBSA, state, region, and division?
   - Answer: Compute for all support geogrpahies.

2. Zillow inclusion timing
   - Should Zillow metrics be included in the first pass of `gold.housing_core_wide`, or should we ship an ACS/HUD/BPS version first and add Zillow after?
   - Answer: Start with a supplement gold table for Zillow metrics, we can then test to see how it fits into the core housing gold table.

3. Migration table scope
   - Should `gold.migration_wide` include IRS migration in the first version, or should we ship ACS mobility and nativity first and layer IRS flows in later?
   - Answer: Do not include IRS migration in the first version, ship ACS mobility and nativity first.

4. Built form and density
   - Do we want tract-based density metrics now, or should they wait until the tract geometry and aggregation method are explicitly approved?
   - Answer: Let's include tract-based density metrics now. We will probably need to get tract sizes ingested first though so map that out.

5. Quality-of-life source scope
   - Which sources are officially in scope for the first version?
   - Candidates mentioned in planning docs include CHR, IPEDS, ACS, transit, broadband, and commute data.

6. Risk and resilience source scope
   - Which sources are officially in scope for the first version?
   - Candidates mentioned in planning docs include FEMA and NOAA.

7. Normalization strategy
   - Should normalized outputs such as z-scores, percentiles, and min-max values live in the same Gold marts as the raw metrics, or in a separate reusable scoring mart?
   - Answer: Build supplemental tables with the normalized outputs for future use and auditability.

8. Composite score policy
   - Do we wait for approved weights before implementing any composite scores, or create placeholder score scaffolds flagged as provisional?

9. RPP and real income treatment
   - For county-level real income and affordability context, do we want explicit county backfill logic from CBSA or state MARPP values before those metrics are considered production-ready?
   - Answer: Yes, use County as a backfill if we don't have CBSA or State MARPP

10. Gold grain policy
   - For new Gold marts, should the default grain always be `geo_level + geo_id + year`, with `period` reserved only for non-ACS economic series, or do we want mixed conventions where inherited source fields stay as `period`?
   - Answer: Default to `geo_level + geo_id + year`

*Likely R Fallback Cases*

These should still be attempted in SQL first, but R may remain the better choice if the SQL becomes overly procedural or difficult to maintain.

- ACS-style CBSA rebasing when multiple grouped weighted aggregations need to stay consistent with existing Silver conventions
- metadata generation from script parsing
- dictionary automation based on repository inspection rather than warehouse transforms

*Not In Scope For Now*

- one dictionary file per replicated staging geography table
- composite scoring without approved business logic
- Gold tables for sources that are still only conceptual and not yet ingested into the warehouse

*Recommended Delivery Order*

1. Rework staging documentation conventions and checklist language.
2. Build `silver.social_infra_base` and `silver.social_infra_kpi`.
3. Fix the Silver CAINC4 write-target bug.
4. Align Silver documentation with actual implemented tables.
5. Build `gold.housing_core_wide` in SQL.
6. Build `gold.migration_wide` in SQL.
7. Build `gold.transport_built_form_wide` in SQL.
8. Build `gold.affordability_wide` in SQL.
9. Pause for follow-up decisions on advanced Gold scope.
10. Build quality-of-life, risk/resilience, normalization, and composite-score layers.

*Reference Sources And Domains*

These are the main metric families and sources currently in scope for warehouse planning.

- ACS
  - age
  - race
  - education
  - income
  - labor
  - housing
  - migration
  - transportation
  - social infrastructure
- BEA
  - GDP
  - income
  - industry structure
  - regional price parity
- BLS
  - LAUS
  - later candidates: QCEW, CES, CPS where justified
- BPS
- HUD
  - CHAS
  - FMR
- IRS
  - migration
- Zillow
  - ZHVI
  - ZORI
- later candidates
  - FEMA
  - FHFA
  - NOAA
  - CHR
  - IPEDS

*Dimensions*

- Crosswalks
  - state <> region <> division
  - state <> county
  - county <> CBSA
  - ZCTA <> county
  - ZCTA <> CBSA
  - ZCTA <> tract
  - tract <> county
- `dim_cbsa`
  - future curated dimension for CBSA metadata and descriptive attributes
- `dim_variables`
  - future curated KPI registry for Gold-facing semantic definitions and usage guidance
