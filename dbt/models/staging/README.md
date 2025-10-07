# Staging Models

This folder contains staging models that clean and standardize raw source data.

## Naming Convention
- All staging models should be prefixed with `stg_`
- Example: `stg_snapshots.sql`, `stg_families.sql`

## Purpose
Staging models perform:
- Data type casting
- Column renaming for consistency
- Basic data cleaning (nulls, duplicates)
- Timestamp conversions
- Joining related source tables when needed

Staging models should NOT contain business logic or complex transformations.