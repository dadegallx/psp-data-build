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
            {'columns': ['snapshot_type']},
            {'columns': ['status_label']},
            {'columns': ['is_last']}
        ]
    )
}}

{#
    INDICATORS MODEL FOR TIME-SERIES ANALYSIS (PRE-AGGREGATED, LONG FORMAT)

    Grain: One row per indicator × snapshot_type × status_label × organization dimensions

    This model aggregates indicator responses into a long format with one row per
    status type (Green, Yellow, Red, Skipped) for flexible BI analysis.

    Use Case:
    - Time-series charts by snapshot_type
    - Stacked bar/pie charts by status_label
    - Percentage calculations in semantic layer: SUM(indicator_count) FILTER (WHERE status_label = 'Green') / SUM(indicator_count)

    Optimization: Aggregates on IDs first, then joins text columns.
#}

with fact_data as (
    select * from {{ ref('fact_family_indicator_snapshot') }}
),

-- Step 1: Aggregate on IDs only (efficient - small integers)
aggregated_counts as (
    select
        fact_data.snapshot_number,
        fact_data.is_last,
        fact_data.organization_id,
        fact_data.survey_indicator_id,
        fact_data.survey_definition_id,
        fact_data.project_id,

        -- Aggregated metrics
        count(*) filter (where fact_data.indicator_status_value = 3) as green_count,
        count(*) filter (where fact_data.indicator_status_value = 2) as yellow_count,
        count(*) filter (where fact_data.indicator_status_value = 1) as red_count,
        count(*) filter (where fact_data.indicator_status_value = 0) as skipped_count

    from fact_data
    group by
        fact_data.snapshot_number,
        fact_data.is_last,
        fact_data.organization_id,
        fact_data.survey_indicator_id,
        fact_data.survey_definition_id,
        fact_data.project_id
),

-- Step 2: Unpivot counts into long format
unpivoted as (
    select
        snapshot_number,
        is_last,
        organization_id,
        survey_indicator_id,
        survey_definition_id,
        project_id,
        'Green' as status_label,
        green_count as indicator_count
    from aggregated_counts

    union all

    select
        snapshot_number,
        is_last,
        organization_id,
        survey_indicator_id,
        survey_definition_id,
        project_id,
        'Yellow' as status_label,
        yellow_count as indicator_count
    from aggregated_counts

    union all

    select
        snapshot_number,
        is_last,
        organization_id,
        survey_indicator_id,
        survey_definition_id,
        project_id,
        'Red' as status_label,
        red_count as indicator_count
    from aggregated_counts

    union all

    select
        snapshot_number,
        is_last,
        organization_id,
        survey_indicator_id,
        survey_definition_id,
        project_id,
        'Skipped' as status_label,
        skipped_count as indicator_count
    from aggregated_counts
),

-- Step 3: Join dimension tables to add text columns AFTER aggregation
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
            when unpivoted.snapshot_number = 1 then 'Baseline'
            when unpivoted.snapshot_number = 2 then '1st Follow-up'
            when unpivoted.snapshot_number = 3 then '2nd Follow-up'
            when unpivoted.snapshot_number = 4 then '3rd Follow-up'
            else (unpivoted.snapshot_number - 1)::text || 'th Follow-up'
        end as snapshot_type,

        unpivoted.snapshot_number as snapshot_sequence,
        unpivoted.is_last,

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

        -- Status and count (long format)
        unpivoted.status_label,
        unpivoted.indicator_count

    from unpivoted
    inner join dim_organization
        on unpivoted.organization_id = dim_organization.organization_id
    inner join dim_indicator_questions
        on unpivoted.survey_indicator_id = dim_indicator_questions.survey_indicator_id
    inner join dim_survey_definition
        on unpivoted.survey_definition_id = dim_survey_definition.survey_definition_id
    left join stg_projects
        on unpivoted.project_id = stg_projects.project_id
)

select * from final
