/*
    Data quality test: Snapshot numbers should be logical
    - snapshot_number should be >= 1
    - If is_baseline is true, snapshot_number should be 1
    - If snapshot_number is 1, is_baseline should be true

    This ensures consistency between the flag and the number.
*/

with inconsistent_snapshots as (
    select
        snapshot_id,
        family_id,
        snapshot_number,
        is_baseline
    from {{ ref('fact_snapshot') }}
    where
        snapshot_number < 1  -- Invalid snapshot number
        or (is_baseline = true and snapshot_number != 1)  -- Baseline flag mismatch
        or (snapshot_number = 1 and is_baseline = false)  -- Number=1 but not baseline
)

-- Test passes when no rows are returned (all snapshot numbers are consistent)
select * from inconsistent_snapshots
