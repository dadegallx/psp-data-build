{{
    config(
        materialized='table',
        tags=['dashboard'],
        indexes=[
            {'columns': ['snapshot_number', 'has_followup_data']},
            {'columns': ['organization_name']},
            {'columns': ['application_name']},
            {'columns': ['snapshot_year']},
            {'columns': ['family_country']}
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

dim_survey_definition as (
    select * from {{ ref('dim_survey_definition') }}
),

stg_projects as (
    select * from {{ ref('stg_projects') }}
),

-- Aggregate indicators per family per snapshot
aggregated as (
    select
        -- Grouping keys
        fact.family_id,
        fact.snapshot_id,

        -- Degenerate dimensions (same per group, take any)
        max(fact.snapshot_number) as snapshot_number,
        bool_or(fact.is_last) as is_last,

        -- Foreign keys for joins (same per group, take any)
        max(fact.date_key) as date_key,
        max(fact.organization_id) as organization_id,
        max(fact.survey_definition_id) as survey_definition_id,
        max(fact.project_id) as project_id,  -- Nullable

        -- Counts
        count(*) as total_indicators_answered,
        sum(case when fact.indicator_status_value = 3 then 1 else 0 end) as count_greens,
        sum(case when fact.indicator_status_value = 2 then 1 else 0 end) as count_yellows,
        sum(case when fact.indicator_status_value = 1 then 1 else 0 end) as count_reds,
        sum(case when fact.indicator_status_value is null
                   or fact.indicator_status_value not in (1, 2, 3) then 1 else 0 end) as count_skipped,

        -- Percentages
        round(100.0 * sum(case when fact.indicator_status_value = 3 then 1 else 0 end) / nullif(count(*), 0), 2) as percentage_greens,
        round(100.0 * sum(case when fact.indicator_status_value = 2 then 1 else 0 end) / nullif(count(*), 0), 2) as percentage_yellows,
        round(100.0 * sum(case when fact.indicator_status_value = 1 then 1 else 0 end) / nullif(count(*), 0), 2) as percentage_reds,
        round(100.0 * sum(case when fact.indicator_status_value is null
                               or fact.indicator_status_value not in (1, 2, 3) then 1 else 0 end) / nullif(count(*), 0), 2) as percentage_skipped

    from fact
    group by fact.family_id, fact.snapshot_id
),

-- Add cohort analysis flag
with_cohort_flag as (
    select
        agg.*,
        max(agg.snapshot_number) over (partition by agg.family_id) > 1 as has_followup_data
    from aggregated agg
),

denormalized as (
    select
        -- Snapshot context
        agg.snapshot_id,
        agg.snapshot_number,
        agg.is_last,
        agg.has_followup_data,

        -- Date attributes
        dim_date.date_actual as snapshot_date,
        dim_date.year_number as snapshot_year,
        dim_date.quarter_number as snapshot_quarter,
        dim_date.month_number as snapshot_month,

        -- Family attributes
        dim_family.family_id,
        dim_family.is_anonymous,
        dim_family.country as family_country,
        dim_family.latitude,
        dim_family.longitude,

        -- Organization attributes
        dim_organization.organization_id,
        dim_organization.organization_name,
        dim_organization.organization_country,
        dim_organization.organization_is_active,
        dim_organization.application_id,
        dim_organization.application_name,
        dim_organization.application_country,

        -- Survey attributes
        dim_survey_definition.survey_definition_id,
        dim_survey_definition.survey_code,
        dim_survey_definition.survey_title,
        dim_survey_definition.survey_language,
        dim_survey_definition.survey_is_active,

        -- Project attributes (nullable - only ~1.3% of snapshots have projects)
        stg_projects.project_id,
        stg_projects.project_name,

        -- Aggregated metrics
        agg.total_indicators_answered,
        agg.count_greens,
        agg.count_yellows,
        agg.count_reds,
        agg.count_skipped,
        agg.percentage_greens,
        agg.percentage_yellows,
        agg.percentage_reds,
        agg.percentage_skipped

    from with_cohort_flag agg
    inner join dim_date on agg.date_key = dim_date.date_key
    inner join dim_family on agg.family_id = dim_family.family_id
    inner join dim_organization on agg.organization_id = dim_organization.organization_id
    inner join dim_survey_definition on agg.survey_definition_id = dim_survey_definition.survey_definition_id
    left join stg_projects on agg.project_id = stg_projects.project_id
)

select * from denormalized
