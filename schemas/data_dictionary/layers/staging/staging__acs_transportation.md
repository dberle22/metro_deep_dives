# Data Dictionary: staging ACS Transportation Group

## Overview
- Schema: `staging`
- Group: `ACS Transportation`
- Tables in group: 11
- Row count range across tables: 13 to 433,172

## Tables
- `acs_transport_county`
- `acs_transport_division`
- `acs_transport_place`
- `acs_transport_region`
- `acs_transport_state`
- `acs_transport_tract_fl`
- `acs_transport_tract_ga`
- `acs_transport_tract_nc`
- `acs_transport_tract_sc`
- `acs_transport_us`
- `acs_transport_zcta`

## Contract Summary
- All tables in this group share one contract signature.
- Column count: 39
- Grain: one row per geography-time unit at this subgroup's native level (inferred from table design).

## Shared Columns
- `GEOID`, `year`, `NAME`, `commute_workers_totalE`, `commute_workers_totalM`, `commute_car_truck_vanE`, `commute_car_truck_vanM`, `commute_drove_aloneE`, `commute_drove_aloneM`, `commute_carpoolE`, `commute_carpoolM`, `commute_public_transE`, `commute_public_transM`, `commute_taxicabE`, `commute_taxicabM`, `commute_motorcycleE`, `commute_motorcycleM`, `commute_bicycleE`, `commute_bicycleM`, `commute_walkedE`, `commute_walkedM`, `commute_otherE`, `commute_otherM`, `commute_worked_homeE`, `commute_worked_homeM`, `veh_total_hhE`, `veh_total_hhM`, `veh_0E`, `veh_0M`, `veh_1E`, `veh_1M`, `veh_2E`, `veh_2M`, `veh_3E`, `veh_3M`, `veh_4_plusE`, `veh_4_plusM`, `total_travel_timeE`, `total_travel_timeM`

## Lineage
- scripts/etl/staging/get_acs_transport.R (writes by geography; see dbWriteTable calls)

## Data Quality Notes
- Verify row uniqueness for the subgroup's natural grain keys before Silver transforms.
- Validate expected time coverage and geography coverage for each table in the subgroup.
- Track schema drift by comparing column count/signature against this document on each refresh.

## Known Gaps / To-Dos
- Add explicit pass/fail threshold checks in the staged DQ runner after data dictionary coverage is complete.
