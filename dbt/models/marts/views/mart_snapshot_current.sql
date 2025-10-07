{{ config(
    materialized="view",
    tags=["mart", "view", "current"]
) }}

/*
    Current status view: Shows the most recent snapshot for each family
    Uses is_last_any flag to identify the latest snapshot regardless of completeness
*/

with fact as (
    select * from {{ ref('fact_snapshot') }}
),

current_snapshots as (
    select
        *
    from fact
    where is_last_any = true
)

select * from current_snapshots
