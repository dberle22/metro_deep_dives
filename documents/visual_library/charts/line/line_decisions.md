# Line Chart Decisions

## Decision L-001: Contract requirement by variant
- Question: Should `time_window` always be optional, or required for non-single variants?
- Answer: Keep optional in the base contract, but enforce conditionally by variant in prep/validation rules.
- Status: Open
- Date: 2026-03-02
