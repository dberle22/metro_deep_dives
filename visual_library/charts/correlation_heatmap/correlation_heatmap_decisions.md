# Correlation Heatmap Decisions

## Decision CH-001: Default correlation method
- Question: Which correlation method should the library use by default?
- Answer: Default to Spearman in documentation and smoke tests because it is more robust for monotonic but non-linear KPI relationships.
- Status: Decided
- Date: 2026-04-14
