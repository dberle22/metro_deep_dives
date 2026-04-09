# Layer 04 Tables

This folder holds the table-owned organizational assets for the managed Layer 04 parcel outputs.

Each current Layer 04 table now has:
- a table-owned `.R` build asset
- a companion `.sql` file for future SQL migration or query-spec notes
- a table-owned `.md` summary

Current tables:
- `parcel.parcels_canonical`
- `parcel.parcel_lineage`
- `qa.parcel_validation_results`
- `qa.parcel_unmapped_use_codes`

This pass is organizational only. The assets were extracted from the existing workflow without rebuilding any DuckDB tables.

Primary Layer 04 products:
- `parcel.parcels_canonical`
- `parcel.parcel_lineage`
- `qa.parcel_validation_results`
- `qa.parcel_unmapped_use_codes`

Compatibility products kept for downstream transition are archived under `tables/archive/`:
- `parcel.retail_parcels`
- `parcel.parcel_join_qa`
