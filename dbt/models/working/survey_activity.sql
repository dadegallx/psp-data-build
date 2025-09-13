{{ config(materialized='view') }}

-- Survey collection metrics over time
-- Grain: One row per organization per month

with monthly_snapshots as (
    select
        s.organization_id,
        date_trunc('month', to_timestamp(s.created_at / 1000))::date as year_month,
        s.family_id,
        s.snapshot_number,
        s.created_at / 1000 as created_timestamp,
        f.anonymous,
        case when sns.id is not null then 1 else 0 end as has_stoplight_data
    from {{ source('data_collect', 'snapshot') }} s
    inner join {{ source('data_collect', 'survey_definition') }} sd
        on s.survey_definition_id = sd.id
    left join {{ source('ps_families', 'family') }} f
        on s.family_id = f.family_id
    left join {{ source('data_collect', 'snapshot_stoplight') }} sns
        on s.id = sns.snapshot_id
),

monthly_aggregates as (
    select
        organization_id,
        year_month,
        count(*) as total_surveys_collected,
        sum(case when snapshot_number = 1 then 1 else 0 end) as baseline_surveys,
        sum(case when snapshot_number > 1 then 1 else 0 end) as followup_surveys,
        count(distinct family_id) as unique_families_surveyed,
        sum(case when has_stoplight_data = 1 then 1 else 0 end) as surveys_with_stoplight,
        sum(case when anonymous = true then 1 else 0 end) as anonymous_survey_count
    from monthly_snapshots
    group by organization_id, year_month
),

organization_details as (
    select
        o.id as organization_id,
        o.name as organization_name,
        a.name as hub_name,
        a.country
    from {{ source('ps_network', 'organizations') }} o
    left join {{ source('ps_network', 'applications') }} a
        on o.application_id = a.id
)

select
    ma.organization_id,
    to_char(ma.year_month, 'YYYY-MM') as year_month,
    od.organization_name,
    od.hub_name,
    od.country,
    ma.total_surveys_collected,
    ma.baseline_surveys,
    ma.followup_surveys,
    ma.unique_families_surveyed,
    -- Placeholder for avg_completion_time_minutes - requires additional data
    null::numeric as avg_completion_time_minutes,
    case
        when ma.total_surveys_collected > 0
        then round(ma.surveys_with_stoplight::numeric / ma.total_surveys_collected::numeric, 4)
        else null
    end as stoplight_completion_rate,
    -- Placeholder for surveys_with_priorities - requires priority data
    0 as surveys_with_priorities,
    ma.anonymous_survey_count,
    case
        when ma.total_surveys_collected > 0
        then round(ma.anonymous_survey_count::numeric / ma.total_surveys_collected::numeric, 4)
        else null
    end as anonymous_survey_pct
from monthly_aggregates ma
left join organization_details od
    on ma.organization_id = od.organization_id
order by ma.organization_id, ma.year_month