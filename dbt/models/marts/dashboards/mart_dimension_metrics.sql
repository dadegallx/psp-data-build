{{
  config(
    materialized='table',
    tags=['mart', 'dashboard', 'dimensions']
  )
}}

with latest_metrics as (
    select * from {{ ref('int_latest_metrics') }}
),

dimension_aggregates as (
    select
        -- Grain: Dimension × Organization × Country × Date
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

        -- Aggregate measures
        count(*) as total_indicator_responses,

        -- Green indicators
        sum(case when indicator_status_value = 3 then 1 else 0 end) as green_count,

        -- Yellow indicators
        sum(case when indicator_status_value = 2 then 1 else 0 end) as yellow_count,

        -- Red indicators
        sum(case when indicator_status_value = 1 then 1 else 0 end) as red_count,

        -- Skipped indicators
        sum(case when indicator_status_value is null then 1 else 0 end) as skipped_count,

        -- Total assessed (non-skipped)
        sum(case when indicator_status_value is not null then 1 else 0 end) as total_assessed

    from latest_metrics
    group by
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

final as (
    select
        -- Grain identifiers
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
        total_indicator_responses,
        total_assessed,
        green_count,
        yellow_count,
        red_count,
        skipped_count,

        -- Percentages (based on total responses including skipped)
        round(100.0 * green_count / nullif(total_indicator_responses, 0), 1) as green_pct,
        round(100.0 * yellow_count / nullif(total_indicator_responses, 0), 1) as yellow_pct,
        round(100.0 * red_count / nullif(total_indicator_responses, 0), 1) as red_pct,
        round(100.0 * skipped_count / nullif(total_indicator_responses, 0), 1) as skipped_pct

    from dimension_aggregates
)

select * from final
