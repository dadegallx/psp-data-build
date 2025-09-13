{{ config(materialized='view') }}

-- Currently active survey configurations by organization
-- Grain: One row per active survey definition

with base_definitions as (
    select
        sd.id as survey_definition_id,
        sd.survey_code,
        sd.title as survey_title,
        s.organization_id,
        sd.lang as language,
        sd.stoplight_type,
        sd.minimum_priorities as minimum_priorities_required,
        sd.active,
        sd.current,
        extract(epoch from sd.created_at) as created_timestamp
    from {{ source('data_collect', 'survey_definition') }} sd
    left join {{ source('data_collect', 'snapshot') }} s
        on sd.id = s.survey_definition_id
    where sd.active = true
        and sd.current = true
),

indicator_counts as (
    select
        ss.survey_definition_id,
        count(distinct ss.id) as total_indicators
    from {{ source('data_collect', 'survey_stoplight') }} ss
    group by ss.survey_definition_id
),

economic_question_counts as (
    select
        se.survey_definition_id,
        count(distinct se.id) as total_economic_questions
    from {{ source('data_collect', 'survey_economic') }} se
    group by se.survey_definition_id
),

usage_stats as (
    select
        s.survey_definition_id,
        max(s.created_at / 1000) as last_snapshot_timestamp,
        count(distinct s.id) as total_snapshots_collected
    from {{ source('data_collect', 'snapshot') }} s
    group by s.survey_definition_id
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
    bd.survey_definition_id,
    bd.survey_code,
    bd.survey_title,
    bd.organization_id,
    od.organization_name,
    od.hub_name,
    od.country,
    bd.language,
    bd.stoplight_type,
    coalesce(ic.total_indicators, 0) as total_indicators,
    coalesce(eqc.total_economic_questions, 0) as total_economic_questions,
    bd.minimum_priorities_required,
    bd.current as is_current_version,
    to_timestamp(bd.created_timestamp)::date as created_date,
    case
        when us.last_snapshot_timestamp is not null
        then to_timestamp(us.last_snapshot_timestamp)::date
        else null
    end as last_snapshot_date,
    coalesce(us.total_snapshots_collected, 0) as total_snapshots_collected
from base_definitions bd
left join indicator_counts ic
    on bd.survey_definition_id = ic.survey_definition_id
left join economic_question_counts eqc
    on bd.survey_definition_id = eqc.survey_definition_id
left join usage_stats us
    on bd.survey_definition_id = us.survey_definition_id
left join organization_details od
    on bd.organization_id = od.organization_id