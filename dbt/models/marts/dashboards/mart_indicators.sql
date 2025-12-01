{{
    config(
        materialized='table',
        tags=['dashboard'],
        indexes=[
            {'columns': ['family_id']},
            {'columns': ['organization_name']},
            {'columns': ['application_name']},
            {'columns': ['indicator_name']},
            {'columns': ['has_followup_data']},
            {'columns': ['baseline_value']},
            {'columns': ['latest_followup_value']}
        ]
    )
}}

{#
    PIVOTED INDICATOR MODEL FOR BASELINE VS FOLLOW-UP COMPARISON

    Grain: One row per family × survey_indicator

    This model pivots snapshot data to enable easy comparison between:
    - Baseline (snapshot_number = 1)
    - First follow-up (snapshot_number = 2)
    - Latest follow-up (max snapshot_number where > 1)

    Note: Indicators added in follow-ups will have NULL baseline columns.
          Families with no follow-up will have NULL follow-up columns.
#}

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

dim_survey_definition as (
    select * from {{ ref('dim_survey_definition') }}
),

-- Get all unique family × indicator combinations with their context
-- Use MIN to get consistent values (they should be the same across snapshots)
all_family_indicators as (
    select
        family_id,
        survey_indicator_id,
        min(organization_id) as organization_id,
        min(survey_definition_id) as survey_definition_id
    from fact
    group by family_id, survey_indicator_id
),

-- Count total snapshots per family × indicator
snapshot_counts as (
    select
        family_id,
        survey_indicator_id,
        count(*) as total_snapshots
    from fact
    group by family_id, survey_indicator_id
),

-- Baseline data (snapshot_number = 1)
baseline_data as (
    select
        f.family_id,
        f.survey_indicator_id,
        d.date_actual as baseline_date,
        f.indicator_status_value as baseline_value,
        f.project_id as baseline_project_id
    from fact f
    inner join dim_date d on f.date_key = d.date_key
    where f.snapshot_number = 1
),

-- First follow-up data (snapshot_number = 2)
first_followup_data as (
    select
        f.family_id,
        f.survey_indicator_id,
        d.date_actual as first_followup_date,
        f.indicator_status_value as first_followup_value
    from fact f
    inner join dim_date d on f.date_key = d.date_key
    where f.snapshot_number = 2
),

-- Latest follow-up data (max snapshot_number where > 1)
latest_followup_ranked as (
    select
        f.family_id,
        f.survey_indicator_id,
        d.date_actual as latest_followup_date,
        f.indicator_status_value as latest_followup_value,
        row_number() over (
            partition by f.family_id, f.survey_indicator_id
            order by f.snapshot_number desc
        ) as rn
    from fact f
    inner join dim_date d on f.date_key = d.date_key
    where f.snapshot_number > 1
),

latest_followup_data as (
    select
        family_id,
        survey_indicator_id,
        latest_followup_date,
        latest_followup_value
    from latest_followup_ranked
    where rn = 1
),

-- Pivot all the data together
pivoted as (
    select
        afi.family_id,
        afi.survey_indicator_id,
        afi.organization_id,
        afi.survey_definition_id,

        -- Snapshot counts
        sc.total_snapshots,

        -- Baseline
        bd.baseline_date,
        bd.baseline_value,
        bd.baseline_project_id,

        -- First follow-up
        ffd.first_followup_date,
        ffd.first_followup_value,

        -- Latest follow-up
        lfd.latest_followup_date,
        lfd.latest_followup_value

    from all_family_indicators afi
    inner join snapshot_counts sc
        on afi.family_id = sc.family_id
        and afi.survey_indicator_id = sc.survey_indicator_id
    left join baseline_data bd
        on afi.family_id = bd.family_id
        and afi.survey_indicator_id = bd.survey_indicator_id
    left join first_followup_data ffd
        on afi.family_id = ffd.family_id
        and afi.survey_indicator_id = ffd.survey_indicator_id
    left join latest_followup_data lfd
        on afi.family_id = lfd.family_id
        and afi.survey_indicator_id = lfd.survey_indicator_id
),

final as (
    select
        -- Family identifier
        p.family_id,

        -- Organization context
        dim_organization.organization_name,
        dim_organization.application_name,

        -- Survey context
        dim_survey_definition.survey_title,

        -- Project context (from baseline, nullable)
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

        -- Snapshot count
        p.total_snapshots,

        -- Baseline columns
        p.baseline_date,
        p.baseline_value,
        case
            when p.baseline_value = 1 then 'Red'
            when p.baseline_value = 2 then 'Yellow'
            when p.baseline_value = 3 then 'Green'
            when p.baseline_value is null then null
            else 'Skipped'
        end as baseline_label,

        -- First follow-up columns
        p.first_followup_date,
        p.first_followup_value,
        case
            when p.first_followup_value = 1 then 'Red'
            when p.first_followup_value = 2 then 'Yellow'
            when p.first_followup_value = 3 then 'Green'
            when p.first_followup_value is null then null
            else 'Skipped'
        end as first_followup_label,

        -- Latest follow-up columns
        p.latest_followup_date,
        p.latest_followup_value,
        case
            when p.latest_followup_value = 1 then 'Red'
            when p.latest_followup_value = 2 then 'Yellow'
            when p.latest_followup_value = 3 then 'Green'
            when p.latest_followup_value is null then null
            else 'Skipped'
        end as latest_followup_label,

        -- Delta columns (positive = improvement, negative = decline)
        p.first_followup_value - p.baseline_value as baseline_to_first_diff,
        p.latest_followup_value - p.baseline_value as baseline_to_latest_diff,

        -- Cohort flag
        p.first_followup_value is not null as has_followup_data

    from pivoted p
    inner join dim_family
        on p.family_id = dim_family.family_id
    inner join dim_organization
        on p.organization_id = dim_organization.organization_id
    inner join dim_indicator_questions
        on p.survey_indicator_id = dim_indicator_questions.survey_indicator_id
    inner join dim_survey_definition
        on p.survey_definition_id = dim_survey_definition.survey_definition_id
    left join stg_projects
        on p.baseline_project_id = stg_projects.project_id
)

select * from final
