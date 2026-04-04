# Layer 03 - Zone Build

This layer moves contiguity and cluster zone construction upstream.

## First Slice
- Shared zone-build functions extracted from Section 04 build logic.
- DuckDB publication for contiguity and cluster zone products.
- Section 04 continues to write legacy-compatible artifacts from the same prepared products.

## Current Products
- `zones.zone_input_candidates`
- `zones.contiguity_zone_components`
- `zones.contiguity_zone_summary`
- `zones.contiguity_zone_geometries`
- `zones.cluster_assignments`
- `zones.cluster_zone_summary`
- `zones.cluster_zone_geometries`

## Still Pending
- independent runner integration
- zone QA tables in `qa`
- serving-layer handoff into parcel prep
