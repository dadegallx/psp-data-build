{{
    config(
        materialized='table',
        tags=['dashboard'],
        indexes=[
            {'columns': ['snapshot_number', 'has_followup_data']},
            {'columns': ['indicator_label']},
            {'columns': ['organization_name']},
            {'columns': ['application_name']},
            {'columns': ['snapshot_year']}
        ]
    )
}}

with fact as (
    select * from {{ ref('fact_family_indicator_snapshot') }}
),

dim_date as (
    select * from {{ ref('dim_date') }}
),

dim_family as (
    select * from {{ ref('dim_family') }}
),

dim_organization as (
    select * from {{ ref('dim_organization') }}
),

dim_indicator_questions as (
    select * from {{ ref('dim_indicator_questions') }}
),

stg_projects as (
    select * from {{ ref('stg_projects') }}
),

final as (
    select
        -- Snapshot context
        fact.snapshot_id,
        fact.snapshot_number,
        fact.is_last,

        -- Date attributes
        dim_date.date_actual as snapshot_date,
        dim_date.year_number as snapshot_year,
        dim_date.quarter_number as snapshot_quarter,
        dim_date.month_number as snapshot_month,

        -- Family identifier
        dim_family.family_id,

        -- Organization context
        dim_organization.organization_name,
        dim_organization.application_name,

        -- Project context (nullable - only ~1.3% of snapshots have projects)
        stg_projects.project_name,

        -- Indicator definition (canonical English for aggregation)
        dim_indicator_questions.indicator_name,
        dim_indicator_questions.dimension_name,

        -- Indicator definition (localized for display)
        dim_indicator_questions.survey_indicator_short_name,
        dim_indicator_questions.survey_indicator_question_text,
        dim_indicator_questions.survey_indicator_description,

        -- Color criteria descriptions
        dim_indicator_questions.red_criteria_description,
        dim_indicator_questions.yellow_criteria_description,
        dim_indicator_questions.green_criteria_description,

        -- Indicator status value and label
        fact.indicator_status_value as indicator_value,
        case
            when fact.indicator_status_value = 1 then 'Red'
            when fact.indicator_status_value = 2 then 'Yellow'
            when fact.indicator_status_value = 3 then 'Green'
            else 'Skipped'
        end as indicator_label,

        -- Cohort analysis flag (true if family has at least one follow-up survey)
        max(fact.snapshot_number) over (partition by dim_family.family_id) > 1 as has_followup_data

    from fact
    inner join dim_date
        on fact.date_key = dim_date.date_key
    inner join dim_family
        on fact.family_id = dim_family.family_id
    inner join dim_organization
        on fact.organization_id = dim_organization.organization_id
    inner join dim_indicator_questions
        on fact.survey_indicator_id = dim_indicator_questions.survey_indicator_id
    left join stg_projects
        on fact.project_id = stg_projects.project_id
)

select * from final
