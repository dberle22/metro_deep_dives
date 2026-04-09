# `qa.market_serving_validation_results`

- Grain: one row per `market_key`, `check_name`, `dataset`
- Published by: `qa.market_serving_validation_results.R`
- Managed build asset: `notebooks/retail_opportunity_finder/data_platform/layers/05_market_serving_prep/tables/qa.market_serving_validation_results.R`
- Status: proposed for multi-market generalization

## Table role

- Quality assurance checks for market serving data integrity
- Monitors data processing quality and identifies potential issues
- Supports automated validation of multi-market serving layer outputs

## Key columns

- `market_key`, `cbsa_code`: Market identification
- `check_name`: Specific validation check identifier
- `severity`: "error" or "warning" (affects pass/fail logic)
- `dataset`: Target table being validated
- `metric_value`: Numeric result of the check
- `pass`: Boolean indicating if check passed
- `details`: Descriptive explanation of check results

## Validation checks

- **serving_retail_parcel_missing_geometry**: Parcels without geometry after RDS join
- **serving_tract_assignment_unassigned_parcels**: Parcels without tract assignment
- **serving_retail_intensity_unique_tract**: Duplicate tract rows in intensity table
- **serving_zone_overlay_unique_zone**: Duplicate zone rows in overlay table
- **serving_shortlist_unique_zone_parcel**: Duplicate parcel-zone combinations in shortlist
- **serving_shortlist_missing_scores**: Shortlist rows with missing scores

## Dependencies

- All serving tables for comprehensive QA coverage

## Business context

- Ensures data quality for downstream retail opportunity analysis
- Provides early warning of processing issues across markets
- Supports automated monitoring and alerting for data pipeline health