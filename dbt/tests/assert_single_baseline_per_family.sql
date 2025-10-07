/*
    Business rule test: Each family should have at most one baseline snapshot
    (snapshot_number = 1 or is_baseline = true)

    This test will warn if any family has multiple baseline records,
    which indicates a data quality issue in the source data.

    Note: Currently 81 families have multiple baselines - this is a known
    data quality issue that should be addressed in the source system.
*/

{{ config(severity = 'warn') }}

with baseline_counts as (
    select
        family_id,
        count(*) as baseline_count
    from {{ ref('fact_snapshot') }}
    where is_baseline = true
    group by family_id
    having count(*) > 1
)

-- Test passes when no rows are returned (no families with multiple baselines)
select * from baseline_counts
