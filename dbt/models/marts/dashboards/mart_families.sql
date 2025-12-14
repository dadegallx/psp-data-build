{{
    config(
        materialized='table',
        alias='Families',
        tags=['dashboard'],
        indexes=[
            {'columns': ['family_id']},
            {'columns': ['application_id']},
            {'columns': ['hub_name']},
            {'columns': ['organization_name']},
            {'columns': ['country']},
            {'columns': ['baseline_date']},
            {'columns': ['latest_date']}
        ]
    )
}}

{#
    FAMILIES DASHBOARD MODEL

    Grain: One row per family

    Purpose: Analyze the current status, history, and progress of families
    in the Poverty Stoplight program.

    Note: For families with multiple organizations (0.22%), we use the
    organization from their latest snapshot (is_last=true).
#}

with families as (
    select * from {{ ref('dim_family') }}
),

organizations as (
    select * from {{ ref('dim_organization') }}
),

-- Get organization from latest snapshot for each family
latest_snapshot_org as (
    select
        family_id,
        organization_id
    from {{ ref('fact_snapshots') }}
    where is_last = true
),

-- Aggregate snapshot data per family
snapshot_agg as (
    select
        family_id,
        count(*) as surveys_taken,
        min(case when snapshot_number = 1 then snapshot_date end)::date as baseline_date,
        max(case when is_last = true then snapshot_date end)::date as latest_date
    from {{ ref('fact_snapshots') }}
    group by family_id
),

-- Aggregate family member data
member_agg as (
    select
        family_id,
        count(*) as members_count,
        count(*) filter (where gender = 'Male') as members_male,
        count(*) filter (where gender = 'Female') as members_female,
        count(*) filter (where gender = 'Other') as members_other
    from {{ ref('stg_family_members') }}
    group by family_id
),

final as (
    select
        -- Primary key & RLS
        f.family_id,
        org.application_id,  -- for RLS filtering

        -- Dimensions (Organization context from latest snapshot)
        org.organization_name,
        org.application_name as hub_name,
        org.application_country_code as country,

        -- Geographic
        f.latitude,
        f.longitude,

        -- Date dimensions
        sa.baseline_date,
        sa.latest_date,

        -- Member metrics
        coalesce(ma.members_count, 0) as members_count,
        coalesce(ma.members_male, 0) as members_male,
        coalesce(ma.members_female, 0) as members_female,
        coalesce(ma.members_other, 0) as members_other,

        -- Survey metrics
        sa.surveys_taken,

        -- Avg time between surveys (days)
        -- Only meaningful if surveys_taken > 1
        case
            when sa.surveys_taken > 1
            then (sa.latest_date - sa.baseline_date)::float / (sa.surveys_taken - 1)
            else null
        end as avg_days_between_surveys

    from families f
    inner join latest_snapshot_org lso
        on f.family_id = lso.family_id
    inner join organizations org
        on lso.organization_id = org.organization_id
    inner join snapshot_agg sa
        on f.family_id = sa.family_id
    left join member_agg ma
        on f.family_id = ma.family_id
)

select * from final
