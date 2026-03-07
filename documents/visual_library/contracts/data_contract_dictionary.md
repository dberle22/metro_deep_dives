# Visual Contract Data Dictionary

## Purpose
Provide shared field definitions across chart contracts so each chart is not defined from scratch.

## Core Fields
- `geo_level` (character): Geography granularity (`us`, `region`, `division`, `state`, `cbsa`, `county`, `tract`, `zcta`).
- `geo_id` (character): Stable identifier for the geography.
- `geo_name` (character): Display name for the geography.
- `period` (integer/date): Time key (year now; extendable to date/quarter/month).
- `metric_id` (character): Stable metric identifier.
- `metric_label` (character): Human-readable metric label.
- `metric_value` (numeric): Value for the metric at the specified grain/time.
- `source` (character): Source system/table.
- `vintage` (character): Data release/version stamp.

## Variant and Metadata Fields
- `time_window` (character): Transform window (`level`, `indexed`, `rolling_3yr`, etc.).
- `group` (character): Grouping dimension for color/facet/benchmarks.
- `highlight_flag` (logical): Marks selected geographies.
- `benchmark_value` (numeric): Benchmark series value when encoded as separate field.
- `index_base_period` (integer): Base period for indexed transforms.
- `note` (character): Data caveat or break annotation.

## Paired-Metric Fields (Scatter and similar)
- `x_metric_id`, `x_metric_label`, `x_metric_value`
- `y_metric_id`, `y_metric_label`, `y_metric_value`
- `size_metric_value` (optional)

## Contract Rules
- Required vs optional status is chart-specific.
- `metric_id` semantics must be consistent across geographies within a comparison.
- `period` type must be consistent within a dataset.
