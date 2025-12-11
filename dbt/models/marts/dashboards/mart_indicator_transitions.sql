{{
    config(
        materialized='table',
        alias='Indicator Transitions',
        tags=['dashboard'],
        indexes=[
            {'columns': ['application_id']},
            {'columns': ['hub_name']},
            {'columns': ['organization_name']},
            {'columns': ['indicator_name']},
            {'columns': ['dimension_name']},
            {'columns': ['survey_title']}
        ]
    )
}}

{#
    INDICATOR TRANSITIONS MODEL FOR BASELINE VS LATEST COMPARISON

    Grain: One row per indicator_name × survey_definition_id

    This model aggregates indicator transitions to enable analysis of:
    - Which indicators are improving/worsening across the portfolio
    - Comparison between baseline (snapshot_number = 1) and latest (is_last = true)

    Note: Only includes indicators present in BOTH baseline AND latest snapshots.
          Indicators added or removed between surveys are excluded.
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

-- Baseline indicators (snapshot_number = 1)
baseline as (
    select
        family_id,
        survey_indicator_id,
        organization_id,
        survey_definition_id,
        project_id,
        indicator_status_value as baseline_value
    from fact_data
    where snapshot_number = 1
),

-- Latest indicators (is_last = true, computed in int_snapshots)
latest as (
    select
        family_id,
        survey_indicator_id,
        indicator_status_value as latest_value
    from fact_data
    where is_last = true
),

-- Pair only indicators that exist in BOTH baseline AND latest
paired as (
    select
        b.family_id,
        b.survey_indicator_id,
        b.organization_id,
        b.survey_definition_id,
        b.project_id,
        b.baseline_value,
        l.latest_value
    from baseline b
    inner join latest l
        on b.family_id = l.family_id
        and b.survey_indicator_id = l.survey_indicator_id
),

-- Join dimension attributes before aggregation
with_dimensions as (
    select
        -- RLS and hierarchy
        dim_organization.application_id,
        dim_organization.application_name as hub_name,
        dim_organization.organization_name,
        stg_projects.project_name,  -- nullable

        -- Dimensions for grouping
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

        -- Values for aggregation
        paired.baseline_value,
        paired.latest_value

    from paired
    inner join dim_organization
        on paired.organization_id = dim_organization.organization_id
    inner join dim_indicator_questions
        on paired.survey_indicator_id = dim_indicator_questions.survey_indicator_id
    inner join dim_survey_definition
        on paired.survey_definition_id = dim_survey_definition.survey_definition_id
    left join stg_projects
        on paired.project_id = stg_projects.project_id
),

-- Aggregate by indicator × survey dimensions
aggregated as (
    select
        -- RLS and hierarchy
        application_id,
        hub_name,
        organization_name,
        project_name,

        -- Dimensions
        indicator_name,
        dimension_name,
        survey_title,

        -- Indicator details (use MIN since they're the same within group)
        min(survey_indicator_short_name) as survey_indicator_short_name,
        min(survey_indicator_question_text) as survey_indicator_question_text,
        min(survey_indicator_description) as survey_indicator_description,
        min(red_criteria_description) as red_criteria_description,
        min(yellow_criteria_description) as yellow_criteria_description,
        min(green_criteria_description) as green_criteria_description,

        -- Baseline Status Metrics
        count(*) filter (where baseline_value in (1, 2, 3)) as baseline_valid_responses,
        count(*) filter (where baseline_value is null or baseline_value not in (1, 2, 3)) as baseline_skipped,
        count(*) filter (where baseline_value = 3) as baseline_green_count,
        count(*) filter (where baseline_value = 2) as baseline_yellow_count,
        count(*) filter (where baseline_value = 1) as baseline_red_count,

        -- Latest Status Metrics
        count(*) filter (where latest_value in (1, 2, 3)) as latest_valid_responses,
        count(*) filter (where latest_value is null or latest_value not in (1, 2, 3)) as latest_skipped,
        count(*) filter (where latest_value = 3) as latest_green_count,
        count(*) filter (where latest_value = 2) as latest_yellow_count,
        count(*) filter (where latest_value = 1) as latest_red_count,

        -- Impact Metrics: Improvements (Baseline → Latest)
        count(*) filter (where baseline_value = 1 and latest_value = 3) as improved_red_to_green,
        count(*) filter (where baseline_value = 1 and latest_value = 2) as improved_red_to_yellow,
        count(*) filter (where baseline_value = 2 and latest_value = 3) as improved_yellow_to_green,

        -- Impact Metrics: Declines (Baseline → Latest)
        count(*) filter (where baseline_value = 3 and latest_value = 1) as worsened_green_to_red,
        count(*) filter (where baseline_value = 3 and latest_value = 2) as worsened_green_to_yellow,
        count(*) filter (where baseline_value = 2 and latest_value = 1) as worsened_yellow_to_red

    from with_dimensions
    group by
        application_id,
        hub_name,
        organization_name,
        project_name,
        indicator_name,
        dimension_name,
        survey_title
),

final as (
    select
        -- RLS and hierarchy
        application_id,
        hub_name,
        organization_name,
        project_name,

        -- Dimensions
        indicator_name,
        dimension_name,
        survey_title,

        -- Indicator Details
        survey_indicator_short_name,
        survey_indicator_question_text,
        survey_indicator_description,
        red_criteria_description,
        yellow_criteria_description,
        green_criteria_description,

        -- Baseline Status Metrics
        baseline_valid_responses,
        baseline_skipped,
        baseline_green_count,
        baseline_yellow_count,
        baseline_red_count,

        -- Latest Status Metrics
        latest_valid_responses,
        latest_skipped,
        latest_green_count,
        latest_yellow_count,
        latest_red_count,

        -- Impact Metrics: Improvements
        improved_red_to_green,
        improved_red_to_yellow,
        improved_yellow_to_green,

        -- Impact Metrics: Declines
        worsened_green_to_red,
        worsened_green_to_yellow,
        worsened_yellow_to_red

    from aggregated
)

select * from final
