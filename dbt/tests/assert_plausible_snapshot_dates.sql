/*
    Data quality test: Snapshot timestamps should be within plausible range
    (between 2000-01-01 and 1 day in the future)

    This catches issues with millisecond epoch conversion or data entry errors.
*/

with invalid_dates as (
    select
        snapshot_id,
        family_id,
        snapshot_ts,
        snapshot_number
    from {{ ref('fact_snapshot') }}
    where
        snapshot_ts < '2000-01-01'::timestamp
        or snapshot_ts > current_timestamp + interval '1 day'
)

-- Test passes when no rows are returned (all dates are plausible)
select * from invalid_dates
