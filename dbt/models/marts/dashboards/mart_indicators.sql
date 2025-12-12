{{
    config(
        materialized='view',
        alias='Indicators',
        tags=['dashboard']
    )
}}

{#
    INDICATORS MODEL FOR TIME-SERIES ANALYSIS

    Grain: One row per family × indicator × snapshot (family_id × survey_indicator_id × snapshot_id)

    This model includes ALL indicator responses across all snapshots
    to enable time-series style charts with Baseline, 1st Follow-up, 2nd Follow-up, etc.

    Snapshot types (consistent with mart_assessments):
    - 'Baseline' = snapshot_number = 1
    - '1st Follow-up' = snapshot_number = 2
    - '2nd Follow-up' = snapshot_number = 3
    - etc.
#}

with fact_data as (
    select * from {{ ref('fact_family_indicator_snapshot') }}
),

dim_organization as (
    select * from {{ ref('dim_organization') }}
),

dim_indicator_questions as (
    select * from {{ ref('dim_indicator_questions') }}
),

dim_survey_definition as (
    select * from {{ ref('dim_survey_definition') }}
),

stg_projects as (
    select * from {{ ref('stg_projects') }}
),

-- Join dimension attributes
final as (
    select
        -- Primary key components
        fact_data.family_id,

        -- Snapshot type (consistent with mart_assessments)
        case
            when fact_data.snapshot_number = 1 then 'Baseline'
            when fact_data.snapshot_number = 2 then '1st Follow-up'
            when fact_data.snapshot_number = 3 then '2nd Follow-up'
            when fact_data.snapshot_number = 4 then '3rd Follow-up'
            else (fact_data.snapshot_number - 1)::text || 'th Follow-up'
        end as snapshot_type,

        fact_data.snapshot_number as snapshot_sequence,

        -- RLS and hierarchy
        dim_organization.application_id,
        dim_organization.application_name as hub_name,
        dim_organization.organization_name,
        stg_projects.project_name,  -- nullable

        -- Dimensions
        dim_indicator_questions.indicator_name,
        dim_indicator_questions.dimension_name,
        dim_survey_definition.survey_title,

        -- Indicator details (for display/tooltips)
        dim_indicator_questions.survey_indicator_short_name,
        dim_indicator_questions.survey_indicator_question_text,
        dim_indicator_questions.survey_indicator_description,
        dim_indicator_questions.red_criteria_description,
        dim_indicator_questions.yellow_criteria_description,
        dim_indicator_questions.green_criteria_description,

        -- Status value and label
        fact_data.indicator_status_value as status_value,
        case
            when fact_data.indicator_status_value = 1 then 'Red'
            when fact_data.indicator_status_value = 2 then 'Yellow'
            when fact_data.indicator_status_value = 3 then 'Green'
            else 'Skipped'
        end as status_label

    from fact_data
    inner join dim_organization
        on fact_data.organization_id = dim_organization.organization_id
    inner join dim_indicator_questions
        on fact_data.survey_indicator_id = dim_indicator_questions.survey_indicator_id
    inner join dim_survey_definition
        on fact_data.survey_definition_id = dim_survey_definition.survey_definition_id
    left join stg_projects
        on fact_data.project_id = stg_projects.project_id
)

select * from final
