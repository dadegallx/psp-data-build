{{ config(
    materialized="view",
    tags=["mart", "view", "baseline"]
) }}

/*
    Baseline view: Shows the initial (baseline) snapshot for each family
    Uses is_baseline flag (snapshot_number = 1) to identify baseline surveys
*/

with fact as (
    select * from {{ ref('fact_snapshot') }}
),

baseline_snapshots as (
    select
        *
    from fact
    where is_baseline = true
)

select * from baseline_snapshots
