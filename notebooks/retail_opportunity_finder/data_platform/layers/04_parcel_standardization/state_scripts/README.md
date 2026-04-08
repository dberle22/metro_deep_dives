# Layer 04 State Scripts

This folder holds manual parcel ETL scripts that are owned by Layer 04 but are not treated as normal table-owned assets.

These scripts are intentionally state-specific and operational:
- they can be heavy
- they may require state-specific source assumptions
- they should not be mechanically forced into the table-review pattern

Current scripts:
- `fl_parcel_etl_manual_county.R`
  - Florida end-to-end county ETL
  - writes county tabular rows to DuckDB
  - writes county geometry and QA artifacts to disk

Expected pattern:
- one script per state when parcel source systems differ enough that a shared generic runner would add more complexity than value
