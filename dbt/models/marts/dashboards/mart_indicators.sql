{{
    config(
        materialized='table',
        alias='mart_indicators',
        tags=['dashboard'],
        indexes=[
            {'columns': ['application_id']},
            {'columns': ['hub_name']},
            {'columns': ['organization_name']},
            {'columns': ['indicator_name']},
            {'columns': ['snapshot_number']},
            {'columns': ['is_last']},
            {'columns': ['baseline_label']},
            {'columns': ['current_label']},
            {'columns': ['is_priority']},
            {'columns': ['has_achievement']}
        ]
    )
}}

{#
    FLOW-BASED INDICATOR PROGRESS MODEL

    Grain: One row per indicator × snapshot_number × is_last × max_wave_reached
           × baseline_label × previous_label × current_label × organization

    Supports:
    - Sankey diagrams: baseline_label (source) → current_label (target) → family_count (weight)
    - Line charts: % Green over snapshot_number (X-axis)
    - Bar charts: Compare baseline_label vs current_label distributions
    - Cohort analysis: Filter by max_wave_reached for survivor curves

    Chart Queries:
    - Sankey: SELECT baseline_label, current_label, SUM(family_count) WHERE is_last = TRUE
    - Line:   SELECT snapshot_number, SUM(family_count) FILTER (WHERE current_label = 'Green') / SUM(family_count)
    - Bar:    GROUP BY baseline_label vs GROUP BY current_label
    - Cohort: WHERE max_wave_reached >= N
#}

with fact_data as (
    select * from {{ ref('fact_indicators') }}
),

-- Aggregate on IDs and numeric scores (smallest possible keys)
aggregated as (
    select
        organization_id,
        survey_indicator_id,
        survey_definition_id,
        project_id,
        snapshot_number,
        is_last,
        max_snapshot_number,
        baseline_score,
        previous_score,
        current_score,
        
        -- Priority and Achievement Dimensions
        is_priority,
        has_achievement,
        was_priority_in_previous,

        -- Metrics
        count(*) as family_count,
        sum(current_score - baseline_score) as net_change_numeric

    from fact_data
    group by
        organization_id,
        survey_indicator_id,
        survey_definition_id,
        project_id,
        snapshot_number,
        is_last,
        max_snapshot_number,
        baseline_score,
        previous_score,
        current_score,
        is_priority,
        has_achievement,
        was_priority_in_previous
),

-- Join dimension tables for text columns
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
        -- 1. ORGANIZATION / HIERARCHY (RLS)
        dim_organization.application_id,
        dim_organization.application_name as hub_name,
        dim_organization.organization_name,
        stg_projects.project_name,

        -- 2. INDICATOR CONTEXT
        dim_indicator_questions.indicator_name,
        dim_indicator_questions.dimension_name,
        dim_survey_definition.survey_title,

        -- 3. TEMPORAL / COHORT
        case
            when aggregated.snapshot_number = 1 then 'Baseline'
            when aggregated.snapshot_number = 2 then '1st Follow-up'
            when aggregated.snapshot_number = 3 then '2nd Follow-up'
            when aggregated.snapshot_number = 4 then '3rd Follow-up'
            else (aggregated.snapshot_number - 1)::text || 'th Follow-up'
        end as snapshot_type,
        
        aggregated.snapshot_number,
        aggregated.is_last,
        aggregated.max_snapshot_number,

        -- 4. FLOW LABELS (TRANSITIONS)
        case
            when aggregated.baseline_score = 0 then 'Skipped'
            when aggregated.baseline_score = 1 then 'Red'
            when aggregated.baseline_score = 2 then 'Yellow'
            when aggregated.baseline_score = 3 then 'Green'
            else 'N/A'
        end as baseline_label,

        case
            when aggregated.previous_score is null then 'N/A'
            when aggregated.previous_score = 0 then 'Skipped'
            when aggregated.previous_score = 1 then 'Red'
            when aggregated.previous_score = 2 then 'Yellow'
            when aggregated.previous_score = 3 then 'Green'
            else 'N/A'
        end as previous_label,

        case
            when aggregated.current_score = 0 then 'Skipped'
            when aggregated.current_score = 1 then 'Red'
            when aggregated.current_score = 2 then 'Yellow'
            when aggregated.current_score = 3 then 'Green'
            else 'Unknown'
        end as current_label,

        -- 5. PRIORITY & ACHIEVEMENT
        aggregated.is_priority,
        aggregated.has_achievement,
        aggregated.was_priority_in_previous,

        -- 6. METRICS
        aggregated.net_change_numeric,
        aggregated.family_count

    from aggregated
    inner join dim_organization
        on aggregated.organization_id = dim_organization.organization_id
    inner join dim_indicator_questions
        on aggregated.survey_indicator_id = dim_indicator_questions.survey_indicator_id
    inner join dim_survey_definition
        on aggregated.survey_definition_id = dim_survey_definition.survey_definition_id
    left join stg_projects
        on aggregated.project_id = stg_projects.project_id
)

select * from final
