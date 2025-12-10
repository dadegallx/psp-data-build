{{ config(materialized='table') }}

with snapshots as (
    select * from {{ ref('stg_snapshots') }}
),

indicator_agg as (
    select
        snapshot_id,
        count(case when indicator_status_value = 1 then 1 end) as count_red_indicators,
        count(case when indicator_status_value = 2 then 1 end) as count_yellow_indicators,
        count(case when indicator_status_value = 3 then 1 end) as count_green_indicators,
        count(*) as total_indicators
    from {{ ref('stg_snapshot_stoplight') }}
    group by snapshot_id
),

priorities_agg as (
    select
        ss.snapshot_id,
        count(*) as count_priorities
    from {{ ref('stg_snapshot_stoplight_priority') }} p
    join {{ ref('stg_snapshot_stoplight') }} ss on p.snapshot_stoplight_id = ss.snapshot_stoplight_id
    group by ss.snapshot_id
),

achievements_agg as (
    select
        ss.snapshot_id,
        count(*) as count_achievements
    from {{ ref('stg_snapshot_stoplight_achievement') }} a
    join {{ ref('stg_snapshot_stoplight') }} ss on a.snapshot_stoplight_id = ss.snapshot_stoplight_id
    group by ss.snapshot_id
),

families as (
    select * from {{ ref('dim_family') }}
),

organizations as (
    select * from {{ ref('dim_organization') }}
),

final as (
    select
        -- Snapshot Info
        snapshots.snapshot_id,
        snapshots.snapshot_date,
        snapshots.snapshot_number,
        snapshots.is_last,
        
        -- Dimensions
        snapshots.family_id,
        families.is_anonymous,
        families.country as family_country,
        organizations.organization_name,
        organizations.organization_country_code,

        -- Metrics
        coalesce(indicator_agg.count_red_indicators, 0) as count_red_indicators,
        coalesce(indicator_agg.count_yellow_indicators, 0) as count_yellow_indicators,
        coalesce(indicator_agg.count_green_indicators, 0) as count_green_indicators,
        coalesce(indicator_agg.total_indicators, 0) as total_indicators,
        
        coalesce(priorities_agg.count_priorities, 0) as count_priorities,
        coalesce(achievements_agg.count_achievements, 0) as count_achievements

    from snapshots
    left join indicator_agg on snapshots.snapshot_id = indicator_agg.snapshot_id
    left join priorities_agg on snapshots.snapshot_id = priorities_agg.snapshot_id
    left join achievements_agg on snapshots.snapshot_id = achievements_agg.snapshot_id
    left join families on snapshots.family_id = families.family_id
    left join organizations on snapshots.organization_id = organizations.organization_id
)

select * from final
