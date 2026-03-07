# Benchmark Defaults

## Purpose
Define default benchmark comparison sets by geography granularity.

## Decision Log

### BM-001: Metro Area defaults
- Question: What are default benchmarks for Metro Area analyses?
- Answer: Include `Division`, `National`, and `All Other Metro Areas`.
- Status: Decided
- Date: 2026-03-02

### BM-002: State defaults
- Question: What are default benchmarks for State analyses?
- Answer: TBD
- Status: Open
- Date: 2026-03-02

### BM-003: County defaults
- Question: What are default benchmarks for County analyses?
- Answer: TBD
- Status: Open
- Date: 2026-03-02

### BM-004: Tract defaults
- Question: What are default benchmarks for Census Tract analyses?
- Answer: TBD
- Status: Open
- Date: 2026-03-02

### BM-005: ZCTA defaults
- Question: What are default benchmarks for ZCTA analyses?
- Answer: TBD
- Status: Open
- Date: 2026-03-02

## Proposed Structure for Implementation
Each benchmark definition should specify:
- `geo_level`
- `benchmark_set_id`
- `included_groups`
- `exclusion_rules`
- `weighting_method` (for example `metro_mean`, `pop_weighted`)
- `notes`
