# Layer 04 Archived Tables

This folder holds superseded Layer 04 table-owned assets that are no longer primary managed products.

Archived compatibility tables:
- `parcel.parcel_join_qa`
- `parcel.retail_parcels`

These assets remain callable because Layer 04 still publishes the corresponding DuckDB tables for downstream compatibility. They are archived here to mark that:
- they are not the preferred primary Layer 04 products
- the active design is centered on `parcel.parcels_canonical` and `parcel.parcel_lineage`
- later layers should migrate away from depending on them directly
