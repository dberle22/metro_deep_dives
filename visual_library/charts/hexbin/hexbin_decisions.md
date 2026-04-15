# Hexbin Decisions

## Decision H-001: Default density mode
- Question: Which density mode should be the default in the shared implementation?
- Answer: Default to hexbin when the `hexbin` package is available and fall back to `geom_bin_2d()` otherwise.
- Status: Decided
- Date: 2026-04-14
