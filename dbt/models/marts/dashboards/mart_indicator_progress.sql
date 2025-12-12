{{
    config(
        materialized='table',
        alias='Indicator Progress',
        tags=['dashboard'],
        indexes=[
            {'columns': ['application_id']},
            {'columns': ['hub_name']},
            {'columns': ['organization_name']},
            {'columns': ['indicator_name']},
            {'columns': ['snapshot_number']},
            {'columns': ['is_last']},
            {'columns': ['baseline_label']},
            {'columns': ['current_label']}
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
    select * from {{ ref('fact_indicator_enriched') }}
),

-- Step 1: Compute max_wave_reached per family
family_max_wave as (
    select
        family_id,
        max(snapshot_number) as max_wave_reached
    from fact_data
    group by family_id
),

-- Step 2: Add max_wave_reached (keep numeric scores for efficient grouping)
fact_with_max_wave as (
    select
        f.organization_id,
        f.survey_indicator_id,
        f.survey_definition_id,
        f.project_id,
        f.snapshot_number,
        f.is_last,
        fmw.max_wave_reached,
        f.current_score,
        f.baseline_score,
        f.previous_score

    from fact_data f
    inner join family_max_wave fmw
        on f.family_id = fmw.family_id
),

-- Step 3: Aggregate on IDs and numeric scores (smallest possible keys)
aggregated as (
    select
        organization_id,
        survey_indicator_id,
        survey_definition_id,
        project_id,
        snapshot_number,
        is_last,
        max_wave_reached,
        baseline_score,
        previous_score,
        current_score,

        -- Metrics
        count(*) as family_count,
        sum(current_score - baseline_score) as net_change_numeric

    from fact_with_max_wave
    group by
        organization_id,
        survey_indicator_id,
        survey_definition_id,
        project_id,
        snapshot_number,
        is_last,
        max_wave_reached,
        baseline_score,
        previous_score,
        current_score
),

-- Step 4: Join dimension tables for text columns
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
        -- Snapshot type label
        case
            when aggregated.snapshot_number = 1 then 'Baseline'
            when aggregated.snapshot_number = 2 then '1st Follow-up'
            when aggregated.snapshot_number = 3 then '2nd Follow-up'
            when aggregated.snapshot_number = 4 then '3rd Follow-up'
            else (aggregated.snapshot_number - 1)::text || 'th Follow-up'
        end as snapshot_type,

        aggregated.snapshot_number,
        aggregated.is_last,
        aggregated.max_wave_reached,

        -- RLS and hierarchy
        dim_organization.application_id,
        dim_organization.application_name as hub_name,
        dim_organization.organization_name,
        stg_projects.project_name,

        -- Indicator dimensions
        dim_indicator_questions.indicator_name,
        dim_indicator_questions.dimension_name,
        dim_survey_definition.survey_title,

        -- Transition columns (convert to labels AFTER aggregation)
        case
            when aggregated.baseline_score = 0 then 'Skipped'
            when aggregated.baseline_score = 1 then 'Red'
            when aggregated.baseline_score = 2 then 'Yellow'
            when aggregated.baseline_score = 3 then 'Green'
        end as baseline_label,

        case
            when aggregated.previous_score is null then null
            when aggregated.previous_score = 0 then 'Skipped'
            when aggregated.previous_score = 1 then 'Red'
            when aggregated.previous_score = 2 then 'Yellow'
            when aggregated.previous_score = 3 then 'Green'
        end as previous_label,

        case
            when aggregated.current_score = 0 then 'Skipped'
            when aggregated.current_score = 1 then 'Red'
            when aggregated.current_score = 2 then 'Yellow'
            when aggregated.current_score = 3 then 'Green'
        end as current_label,

        -- Metrics
        aggregated.family_count,
        aggregated.net_change_numeric

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
