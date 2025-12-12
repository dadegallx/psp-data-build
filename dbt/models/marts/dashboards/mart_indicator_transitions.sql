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
            {'columns': ['baseline_label']},
            {'columns': ['latest_label']},
            {'columns': ['transition_type']}
        ]
    )
}}

{#
    INDICATOR TRANSITIONS MODEL FOR BASELINE VS LATEST COMPARISON

    Grain: One row per (dimension columns) × baseline_label × latest_label
           Pre-aggregated for Sankey diagrams and fast dashboard queries.

    This model pairs baseline and latest indicator values to enable analysis of:
    - Which indicators are improving/worsening across the portfolio
    - Sankey diagrams: baseline_label (source) → latest_label (target) → indicator_count (metric)

    Note: Only includes indicators present in BOTH baseline AND latest snapshots.
          Only valid stoplight values (1=Red, 2=Yellow, 3=Green) are included.
          Skipped (0, NULL) and invalid values are excluded.
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

-- Pair only indicators that exist in BOTH baseline AND latest, only valid stoplight values
paired as (
    select
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
    where b.baseline_value in (1, 2, 3)  -- Red, Yellow, Green only
      and l.latest_value in (1, 2, 3)
),

-- Join dimension attributes and aggregate
final as (
    select
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

        -- Baseline label
        case
            when paired.baseline_value = 1 then 'Red'
            when paired.baseline_value = 2 then 'Yellow'
            when paired.baseline_value = 3 then 'Green'
        end as baseline_label,

        -- Latest label
        case
            when paired.latest_value = 1 then 'Red'
            when paired.latest_value = 2 then 'Yellow'
            when paired.latest_value = 3 then 'Green'
        end as latest_label,

        -- Transition type (for non-Sankey filtering)
        case
            when paired.baseline_value = 1 and paired.latest_value = 3 then 'Red to Green'
            when paired.baseline_value = 1 and paired.latest_value = 2 then 'Red to Yellow'
            when paired.baseline_value = 2 and paired.latest_value = 3 then 'Yellow to Green'
            when paired.baseline_value = 3 and paired.latest_value = 1 then 'Green to Red'
            when paired.baseline_value = 3 and paired.latest_value = 2 then 'Green to Yellow'
            when paired.baseline_value = 2 and paired.latest_value = 1 then 'Yellow to Red'
            when paired.baseline_value = paired.latest_value then 'No Change'
        end as transition_type,

        -- Metric
        count(*) as indicator_count

    from paired
    inner join dim_organization
        on paired.organization_id = dim_organization.organization_id
    inner join dim_indicator_questions
        on paired.survey_indicator_id = dim_indicator_questions.survey_indicator_id
    inner join dim_survey_definition
        on paired.survey_definition_id = dim_survey_definition.survey_definition_id
    left join stg_projects
        on paired.project_id = stg_projects.project_id
    group by
        dim_organization.application_id,
        dim_organization.application_name,
        dim_organization.organization_name,
        stg_projects.project_name,
        dim_indicator_questions.indicator_name,
        dim_indicator_questions.dimension_name,
        dim_survey_definition.survey_title,
        dim_indicator_questions.survey_indicator_short_name,
        dim_indicator_questions.survey_indicator_question_text,
        dim_indicator_questions.survey_indicator_description,
        dim_indicator_questions.red_criteria_description,
        dim_indicator_questions.yellow_criteria_description,
        dim_indicator_questions.green_criteria_description,
        paired.baseline_value,
        paired.latest_value
)

select * from final
