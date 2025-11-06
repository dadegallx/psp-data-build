{{
  config(
    materialized='table',
    tags=['mart', 'dashboard', 'indicators']
  )
}}

with latest_metrics as (
    select * from {{ ref('int_latest_metrics') }}
),

indicator_aggregates as (
    select
        -- Grain: Indicator × Organization × Country × Date
        indicator_id,
        indicator_short_name,
        indicator_code_name,
        dimension_name,
        organization_id,
        organization_name,
        application_id,
        application_name,
        country_code,
        snapshot_date,
        snapshot_year,
        snapshot_quarter,
        snapshot_month,

        -- Count unique families assessed for this indicator
        count(distinct family_id) as total_families_assessed,

        -- Count total responses
        count(*) as total_responses,

        -- Green families
        sum(case when indicator_status_value = 3 then 1 else 0 end) as green_count,

        -- Yellow families
        sum(case when indicator_status_value = 2 then 1 else 0 end) as yellow_count,

        -- Red families
        sum(case when indicator_status_value = 1 then 1 else 0 end) as red_count,

        -- Skipped
        sum(case when indicator_status_value is null then 1 else 0 end) as skipped_count,

        -- Total assessed (non-skipped)
        sum(case when indicator_status_value is not null then 1 else 0 end) as total_assessed

    from latest_metrics
    group by
        indicator_id,
        indicator_short_name,
        indicator_code_name,
        dimension_name,
        organization_id,
        organization_name,
        application_id,
        application_name,
        country_code,
        snapshot_date,
        snapshot_year,
        snapshot_quarter,
        snapshot_month
),

with_percentages as (
    select
        *,

        -- Percentages (based on total responses including skipped)
        round(100.0 * green_count / nullif(total_responses, 0), 1) as green_pct,
        round(100.0 * yellow_count / nullif(total_responses, 0), 1) as yellow_pct,
        round(100.0 * red_count / nullif(total_responses, 0), 1) as red_pct,
        round(100.0 * skipped_count / nullif(total_responses, 0), 1) as skipped_pct

    from indicator_aggregates
),

with_rankings as (
    select
        *,

        -- Rankings for sorting in dashboards
        row_number() over (
            partition by organization_id, country_code, snapshot_date
            order by red_count desc, indicator_short_name
        ) as rank_by_red,

        row_number() over (
            partition by organization_id, country_code, snapshot_date
            order by yellow_count desc, indicator_short_name
        ) as rank_by_yellow,

        -- Priority rank: most red first, then most yellow
        row_number() over (
            partition by organization_id, country_code, snapshot_date
            order by red_count desc, yellow_count desc, indicator_short_name
        ) as rank_by_priority

    from with_percentages
),

final as (
    select
        -- Grain identifiers
        indicator_id,
        indicator_short_name,
        indicator_code_name,
        dimension_name,
        organization_id,
        organization_name,
        application_id,
        application_name,
        country_code,
        snapshot_date,
        snapshot_year,
        snapshot_quarter,
        snapshot_month,

        -- Counts
        total_families_assessed,
        total_responses,
        total_assessed,
        green_count,
        yellow_count,
        red_count,
        skipped_count,

        -- Percentages
        green_pct,
        yellow_pct,
        red_pct,
        skipped_pct,

        -- Rankings
        rank_by_red,
        rank_by_yellow,
        rank_by_priority

    from with_rankings
)

select * from final
