{{ config(
    materialized="view",
    tags=["mart", "view", "dimension", "experimental"]
) }}

/*
    Quick Win: Family × Dimension current state analysis

    Grain: 1 row per family × dimension
    Shows current state distribution and dimension score for each family-dimension combination

    Metrics:
    - pct_red, pct_yellow, pct_green: % of indicators in each color
    - dimension_score: Average score (Red=0, Yellow=0.5, Green=1)
    - indicators_count: Number of indicators in this dimension

    Note: This is experimental. Official KPIs (ΔScore, time-to-green, priority gap)
    will be in Phase 2 with FactIndicatorAssessment.

    Privacy: Propagates anonymous flag; family_id_public masks ID for anonymous families
*/

with base as (
    select *
    from {{ ref('int_indicator_lite') }}
),

agg as (
    select
        family_id,
        organization_id,
        application_id,
        survey_definition_id,
        dimension_id,
        dimension_name,

        -- Reference timestamp
        max(snapshot_ts) as snapshot_ts,

        -- Color distributions (% of indicators in each color)
        avg(case when indicator_value = 1 then 1.0 else 0.0 end) as pct_red,
        avg(case when indicator_value = 2 then 1.0 else 0.0 end) as pct_yellow,
        avg(case when indicator_value = 3 then 1.0 else 0.0 end) as pct_green,

        -- Dimension score (Red=0, Yellow=0.5, Green=1)
        avg(indicator_score) as dimension_score,

        -- Supporting metrics
        count(*) as indicators_count,
        count(case when indicator_value = 1 then 1 end) as red_count,
        count(case when indicator_value = 2 then 1 end) as yellow_count,
        count(case when indicator_value = 3 then 1 end) as green_count,

        -- Privacy flag (if any snapshot/family is anonymous, propagate)
        bool_or(anonymous) as is_anonymous

    from base
    group by
        family_id,
        organization_id,
        application_id,
        survey_definition_id,
        dimension_id,
        dimension_name
)

select
    a.*,

    -- Privacy-aware public ID (mask for anonymous families)
    case
        when is_anonymous then 'ANON'
        else cast(family_id as varchar)
    end as family_id_public

from agg a
