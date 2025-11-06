{{
  config(
    materialized='view',
    tags=['intermediate', 'latest']
  )
}}

with fact as (
    select * from {{ ref('fact_family_indicator_snapshot') }}
),

dim_family as (
    select * from {{ ref('dim_family') }}
),

dim_indicator as (
    select * from {{ ref('dim_indicator') }}
),

dim_organization as (
    select * from {{ ref('dim_organization') }}
),

dim_survey_definition as (
    select * from {{ ref('dim_survey_definition') }}
),

dim_date as (
    select * from {{ ref('dim_date') }}
),

latest_snapshots as (
    select *
    from fact
    where is_last = true  -- Latest surveys only
),

joined as (
    select
        -- Grain identifiers
        fact.family_key,
        fact.indicator_key,
        fact.snapshot_id,

        -- Family attributes
        fam.family_id,
        fam.family_code,
        fam.family_name,
        fam.country_code,
        fam.latitude,
        fam.longitude,

        -- Indicator attributes
        ind.indicator_id,
        ind.indicator_short_name,
        ind.indicator_code_name,
        ind.dimension_name,

        -- Organization attributes
        org.organization_id,
        org.organization_name,
        org.application_id,
        org.application_name,

        -- Survey attributes
        surv.survey_definition_id,
        surv.survey_title,

        -- Date attributes
        dt.date_actual as snapshot_date,
        dt.year_number as snapshot_year,
        dt.quarter_number as snapshot_quarter,
        dt.month_number as snapshot_month,

        -- Degenerate dimensions
        fact.snapshot_number,

        -- Measure
        fact.indicator_status_value

    from latest_snapshots as fact
    inner join dim_family as fam
        on fact.family_key = fam.family_key
    inner join dim_indicator as ind
        on fact.indicator_key = ind.indicator_key
    inner join dim_organization as org
        on fact.organization_key = org.organization_key
    inner join dim_survey_definition as surv
        on fact.survey_definition_key = surv.survey_definition_key
    inner join dim_date as dt
        on fact.date_key = dt.date_key
)

select * from joined
