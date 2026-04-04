# Retail Opportunity Finder Notebook Build

This area is the downstream notebook-serving layer for ROF V2.

## Role
- read prepared DuckDB products and lightweight section artifacts
- run section QA and visual assembly
- keep heavy analytics out of `.qmd` files

## Transition Rule
Existing `sections/` scripts remain active during migration. New notebook-build modules should prefer prepared products from `data_platform/` and only use legacy artifacts when no prepared source exists yet.
