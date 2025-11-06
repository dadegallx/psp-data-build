{{
  config(
    materialized='table',
    tags=['mart', 'dashboard', 'progress', 'comparison']
  )
}}

with baseline as (
    select * from {{ ref('int_baseline_metrics') }}
),

latest as (
    select * from {{ ref('int_latest_metrics') }}
),

-- Identify families with 2+ surveys
families_with_multiple_surveys as (
    select distinct family_id
    from latest
    where snapshot_number >= 2
),

-- Join baseline and latest for families with multiple surveys
progress_comparison as (
    select
        -- Family identifiers
        b.family_id,
        b.family_code,
        b.family_name,

        -- Indicator identifiers
        b.indicator_id,
        b.indicator_short_name,
        b.indicator_code_name,
        b.dimension_name,

        -- Organization attributes (from latest survey)
        l.organization_id,
        l.organization_name,
        l.application_id,
        l.application_name,

        -- Country (from latest survey)
        l.country_code,

        -- Survey counts
        l.snapshot_number as total_surveys_completed,

        -- Baseline survey attributes
        b.snapshot_date as baseline_survey_date,
        b.snapshot_number as baseline_snapshot_number,
        b.indicator_status_value as baseline_status_value,
        case
            when b.indicator_status_value = 3 then 'Green'
            when b.indicator_status_value = 2 then 'Yellow'
            when b.indicator_status_value = 1 then 'Red'
            else 'Skipped'
        end as baseline_status_label,

        -- Latest survey attributes
        l.snapshot_date as latest_survey_date,
        l.snapshot_number as latest_snapshot_number,
        l.indicator_status_value as latest_status_value,
        case
            when l.indicator_status_value = 3 then 'Green'
            when l.indicator_status_value = 2 then 'Yellow'
            when l.indicator_status_value = 1 then 'Red'
            else 'Skipped'
        end as latest_status_label,

        -- Change calculations
        case
            -- Improvement scenarios
            when b.indicator_status_value = 1 and l.indicator_status_value in (2, 3) then true
            when b.indicator_status_value = 2 and l.indicator_status_value = 3 then true
            when b.indicator_status_value is null and l.indicator_status_value is not null then true
            else false
        end as status_improved,

        case
            -- Deterioration scenarios
            when b.indicator_status_value = 3 and l.indicator_status_value in (1, 2) then true
            when b.indicator_status_value = 2 and l.indicator_status_value = 1 then true
            when b.indicator_status_value is not null and l.indicator_status_value is null then true
            else false
        end as status_deteriorated,

        case
            when b.indicator_status_value = l.indicator_status_value then true
            when b.indicator_status_value is null and l.indicator_status_value is null then true
            else false
        end as status_unchanged

    from baseline as b
    inner join families_with_multiple_surveys as fam
        on b.family_id = fam.family_id
    inner join latest as l
        on b.family_id = l.family_id
        and b.indicator_id = l.indicator_id
),

with_change_category as (
    select
        *,
        case
            when status_improved then 'Improved'
            when status_deteriorated then 'Deteriorated'
            when status_unchanged then 'Unchanged'
            else 'Unknown'
        end as change_category

    from progress_comparison
),

final as (
    select
        -- Family identifiers
        family_id,
        family_code,
        family_name,

        -- Indicator identifiers
        indicator_id,
        indicator_short_name,
        indicator_code_name,
        dimension_name,

        -- Organization attributes
        organization_id,
        organization_name,
        application_id,
        application_name,

        -- Country
        country_code,

        -- Survey counts
        total_surveys_completed,

        -- Baseline attributes
        baseline_survey_date,
        baseline_snapshot_number,
        baseline_status_value,
        baseline_status_label,

        -- Latest attributes
        latest_survey_date,
        latest_snapshot_number,
        latest_status_value,
        latest_status_label,

        -- Change indicators
        status_improved,
        status_deteriorated,
        status_unchanged,
        change_category

    from with_change_category
)

select * from final
