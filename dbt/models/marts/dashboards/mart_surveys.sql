{{
    config(
        materialized='table',
        alias='mart_surveys',
        tags=['dashboard'],
        indexes=[
            {'columns': ['application_id']},
            {'columns': ['organization_name']},
            {'columns': ['country_name']},
            {'columns': ['snapshot_date']},
            {'columns': ['is_last']}
        ]
    )
}}

{#
    SURVEYS & DEMOGRAPHICS MODEL (NON-AGGREGATED)

    Grain: One row per snapshot (survey event).
    Volume: ~1M rows (High performance, no aggregation needed).

    This model creates a "Wide" table for Operational & Demographic analysis.
    Unlike mart_indicators (which is deep/tall), this table is shallow/wide.

    Key Answers:
    - "How many families in Paraguay?" -> Count(*) WHERE is_last=TRUE AND country_name='Paraguay'
    - "Avg time between visits?" -> AVG(days_since_previous)
    - "Total surveys conducted?" -> Count(*)
#}

with snapshots as (
    select * from {{ ref('fact_snapshots') }}
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

final as (
    select
        -- 1. IDENTIFIERS (Snapshot)
        snapshots.snapshot_id,
        
        -- 2. MAIN DIMENSIONS (Geography)
        coalesce(dim_family.country_name, 'Unknown') as country_name,

        -- 3. KEY STATUS FLAGS
        snapshots.is_last,
        
        -- 4. OPERATIONAL METRICS
        snapshots.days_since_previous,
        snapshots.days_since_baseline,

        -- 5. TEMPORAL / CHRONOLOGY
        snapshots.snapshot_number,
        snapshots.is_baseline,
        snapshots.snapshot_date,

        -- 6. ORGANIZATION HIERARCHY (RLS)
        dim_organization.application_id,
        dim_organization.application_name as hub_name,
        dim_organization.organization_name,
        stg_projects.project_name,

        -- 7. DETAILED ATTRIBUTES
        dim_family.latitude,
        dim_family.longitude,
        dim_family.is_anonymous,
        dim_survey_definition.survey_title,
        
        -- 8. EXPLICIT AGGREGATORS
        1 as survey_count

    from snapshots
    inner join dim_organization
        on snapshots.organization_id = dim_organization.organization_id
    inner join dim_family
        on snapshots.family_id = dim_family.family_id
    inner join dim_survey_definition
        on snapshots.survey_definition_id = dim_survey_definition.survey_definition_id
    left join stg_projects
        on snapshots.project_id = stg_projects.project_id
)

select * from final
