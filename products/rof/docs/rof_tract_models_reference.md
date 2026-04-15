# Retail Opportunity Finder — Tract Models Reference

## Schema
All tables remain in:
rof_features

New table:
rof_features.tract_models

---

## Core Features (from tract_features)

- pop_growth_3yr
- permits_per_1k_3yr
- density
- price_proxy
- commute_intensity
- median_household_income

Carry identifiers:
- cbsa_code
- tract_geoid

---

## Standardization

Compute z-scores within each CBSA:

- z_pop_growth
- z_permits
- z_density
- z_price
- z_commute
- z_income

Adjust direction:
- z_density_inv = -z_density
- z_price_inv = -z_price

---

## Eligibility Gates

- pop_growth_pctl >= 0.50
- price_proxy_pctl < 0.70
- density_pctl <= 0.70

Outputs:
- eligible_flag
- growth_gate_flag
- price_gate_flag
- density_gate_flag

---

## Models

### 1. Balanced
- 35% pop_growth
- 25% permits
- 15% density_inv
- 10% price_inv
- 10% income
- 5% commute

### 2. Growth
- 45% pop_growth
- 25% permits
- 10% income
- 10% density_inv
- 5% price_inv
- 5% commute

### 3. Value
- 25% pop_growth
- 20% permits
- 10% density_inv
- 30% price_inv
- 10% income
- 5% commute

### 4. Corridor
- 30% commute
- 25% pop_growth
- 15% permits
- 10% density_inv
- 10% income
- 10% price_inv

---

## Score Calculation

Each model:
score = sum(weight * z_feature)

---

## Rankings

For each model:
- rank within CBSA
- national rank (metro-only tracts)

---

## Output Columns (Wide Table)

### Identifiers
- cbsa_code
- tract_geoid

### Raw Features
- pop_growth_3yr
- permits_per_1k_3yr
- density
- price_proxy
- commute_intensity
- median_household_income

### Z-Scores
- z_pop_growth
- z_permits
- z_density
- z_density_inv
- z_price
- z_price_inv
- z_commute
- z_income

### Gates
- growth_gate_flag
- price_gate_flag
- density_gate_flag
- eligible_flag

### Scores
- score_balanced
- score_growth
- score_value
- score_corridor

### Ranks
- rank_balanced_cbsa
- rank_balanced_national
- rank_growth_cbsa
- rank_growth_national
- rank_value_cbsa
- rank_value_national
- rank_corridor_cbsa
- rank_corridor_national