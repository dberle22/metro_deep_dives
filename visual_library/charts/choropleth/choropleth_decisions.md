# Choropleth Decisions

## Decision C-001: Smoke-test rendering
- Question: How should map smoke tests behave before production geometry inputs are wired into gold-backed builds?
- Answer: Allow placeholder diagnostic renders in smoke-test mode and document the geometry dependency explicitly in chart QA notes.
- Status: Decided
- Date: 2026-04-14
