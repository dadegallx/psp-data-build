{{
    config(
        materialized='table',
        alias='Indicators',
        tags=['dashboard'],
        indexes=[
            {'columns': ['application_id']},
            {'columns': ['hub_name']},
            {'columns': ['organization_name']},
            {'columns': ['indicator_name']},
            {'columns': ['dimension_name']},
            {'columns': ['snapshot_type']}
        ]
    )
}}

{#
    INDICATORS MODEL FOR TIME-SERIES ANALYSIS (PRE-AGGREGATED)

    Grain: One row per indicator × snapshot_type × organization dimensions

    This model aggregates indicator responses to show counts of Green/Yellow/Red
    at each snapshot stage (Baseline, 1st Follow-up, etc.) for time-series analysis.

    Optimization: Aggregates on IDs first, then joins text columns to avoid
    large temp files during GROUP BY.
#}

with fact_data as (
    select * from {{ ref('fact_family_indicator_snapshot') }}
),

-- Step 1: Aggregate on IDs only (efficient - small integers)
aggregated_counts as (
    select
        fact_data.snapshot_number,
        fact_data.organization_id,
        fact_data.survey_indicator_id,
        fact_data.survey_definition_id,
        fact_data.project_id,

        -- Aggregated metrics
        count(*) as total_responses,
        count(*) filter (where fact_data.indicator_status_value = 3) as green_count,
        count(*) filter (where fact_data.indicator_status_value = 2) as yellow_count,
        count(*) filter (where fact_data.indicator_status_value = 1) as red_count,
        count(*) filter (where fact_data.indicator_status_value is null) as skipped_count

    from fact_data
    group by
        fact_data.snapshot_number,
        fact_data.organization_id,
        fact_data.survey_indicator_id,
        fact_data.survey_definition_id,
        fact_data.project_id
),

-- Step 2: Join dimension tables to add text columns AFTER aggregation
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

final as (
    select
        -- Snapshot type
        case
            when aggregated_counts.snapshot_number = 1 then 'Baseline'
            when aggregated_counts.snapshot_number = 2 then '1st Follow-up'
            when aggregated_counts.snapshot_number = 3 then '2nd Follow-up'
            when aggregated_counts.snapshot_number = 4 then '3rd Follow-up'
            else (aggregated_counts.snapshot_number - 1)::text || 'th Follow-up'
        end as snapshot_type,

        aggregated_counts.snapshot_number as snapshot_sequence,

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

        -- Aggregated metrics
        aggregated_counts.total_responses,
        aggregated_counts.green_count,
        aggregated_counts.yellow_count,
        aggregated_counts.red_count,
        aggregated_counts.skipped_count

    from aggregated_counts
    inner join dim_organization
        on aggregated_counts.organization_id = dim_organization.organization_id
    inner join dim_indicator_questions
        on aggregated_counts.survey_indicator_id = dim_indicator_questions.survey_indicator_id
    inner join dim_survey_definition
        on aggregated_counts.survey_definition_id = dim_survey_definition.survey_definition_id
    left join stg_projects
        on aggregated_counts.project_id = stg_projects.project_id
)

select * from final
