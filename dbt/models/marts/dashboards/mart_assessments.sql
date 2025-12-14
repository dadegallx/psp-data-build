{{
    config(
        materialized='table',
        alias='Assessments',
        tags=['dashboard'],
        indexes=[
            {'columns': ['family_id']},
            {'columns': ['application_id']},
            {'columns': ['hub_name']},
            {'columns': ['organization_name']},
            {'columns': ['survey_date']},
            {'columns': ['snapshot_type']},
            {'columns': ['snapshot_sequence']},
            {'columns': ['is_last']}
        ]
    )
}}

{#
    ASSESSMENTS MODEL - OPERATIONAL SURVEY TRACKING

    Grain: One row per snapshot (survey submission)

    Purpose: Analyze field activity, monitor survey volume by partner,
    and track the frequency of family interactions over time.
#}

with snapshots as (
    select * from {{ ref('fact_snapshots') }}
),

organizations as (
    select * from {{ ref('dim_organization') }}
),

survey_definitions as (
    select * from {{ ref('dim_survey_definition') }}
),

projects as (
    select * from {{ ref('stg_projects') }}
),

-- Aggregate indicator counts per snapshot
indicator_counts as (
    select
        snapshot_id,
        count(*) filter (where indicator_status_value = 3) as green_count,
        count(*) filter (where indicator_status_value = 2) as yellow_count,
        count(*) filter (where indicator_status_value = 1) as red_count,
        count(*) filter (where indicator_status_value = 0) as skipped_count,
        count(*) filter (where indicator_status_value in (1, 2, 3)) as valid_indicator_count
    from {{ ref('stg_snapshot_stoplight') }}
    group by snapshot_id
),

-- Calculate days since previous survey for each family
snapshots_with_lag as (
    select
        *,
        lag(snapshot_date) over (
            partition by family_id
            order by snapshot_date
        ) as previous_snapshot_date
    from snapshots
),

final as (
    select
        -- Primary key
        s.snapshot_id,

        -- Foreign keys / RLS
        s.family_id,
        org.application_id,

        -- Dimensions
        s.snapshot_date::date as survey_date,
        org.application_name as hub_name,
        org.organization_name,
        proj.project_name,  -- nullable
        sd.survey_title as survey_name,

        -- Snapshot type (dynamic label based on sequence)
        case
            when s.snapshot_number = 1 then 'Baseline'
            when s.snapshot_number = 2 then '1st Follow-up'
            when s.snapshot_number = 3 then '2nd Follow-up'
            when s.snapshot_number = 4 then '3rd Follow-up'
            else (s.snapshot_number - 1)::text || 'th Follow-up'
        end as snapshot_type,

        s.snapshot_number as snapshot_sequence,

        -- Metrics
        case
            when s.snapshot_number = 1 then null  -- Baselines have no previous
            else (s.snapshot_date::date - s.previous_snapshot_date::date)
        end as days_since_last_survey,

        -- Indicator counts (aggregated from stg_snapshot_stoplight)
        coalesce(ic.green_count, 0) as green_count,
        coalesce(ic.yellow_count, 0) as yellow_count,
        coalesce(ic.red_count, 0) as red_count,
        coalesce(ic.skipped_count, 0) as skipped_count,
        coalesce(ic.valid_indicator_count, 0) as valid_indicator_count,

        -- Latest snapshot flag
        s.is_last

    from snapshots_with_lag s
    inner join organizations org
        on s.organization_id = org.organization_id
    inner join survey_definitions sd
        on s.survey_definition_id = sd.survey_definition_id
    left join projects proj
        on s.project_id = proj.project_id
    left join indicator_counts ic
        on s.snapshot_id = ic.snapshot_id
)

select * from final
