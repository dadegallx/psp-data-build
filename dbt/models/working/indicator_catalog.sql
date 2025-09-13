{{ config(materialized='view') }}

-- Master list of all indicator templates with metadata and usage statistics
-- Grain: One row per indicator template

with base_indicators as (
    select
        ssi.id as indicator_template_id,
        ssi.code_name as indicator_code_name,
        ssi.met_short_name as indicator_short_name,
        ssd.met_name as dimension,
        null as measurement_unit,  -- Not available in this table
        'active' as status  -- Assuming all are active for now
    from {{ source('data_collect', 'survey_stoplight_indicator') }} ssi
    left join {{ source('data_collect', 'survey_stoplight_dimension') }} ssd
        on ssi.survey_dimension_id = ssd.id
),

usage_stats as (
    select
        ssi.id as indicator_template_id,
        count(distinct ss.id) as total_implementations,
        count(distinct s.organization_id) as total_organizations_using,
        max(s.created_at / 1000) as last_used_timestamp
    from {{ source('data_collect', 'survey_stoplight_indicator') }} ssi
    left join {{ source('data_collect', 'survey_stoplight') }} ss
        on ssi.id = ss.survey_indicator_id
    left join {{ source('data_collect', 'survey_definition') }} sd
        on ss.survey_definition_id = sd.id
    left join {{ source('data_collect', 'snapshot') }} s
        on sd.id = s.survey_definition_id
    group by ssi.id
),

response_stats as (
    select
        ssi.id as indicator_template_id,
        count(distinct sns.id) as total_responses
    from {{ source('data_collect', 'survey_stoplight_indicator') }} ssi
    left join {{ source('data_collect', 'survey_stoplight') }} ss
        on ssi.id = ss.survey_indicator_id
    left join {{ source('data_collect', 'snapshot') }} s
        on ss.survey_definition_id = s.survey_definition_id
    left join {{ source('data_collect', 'snapshot_stoplight') }} sns
        on s.id = sns.snapshot_id
    group by ssi.id
)

select
    bi.indicator_template_id,
    bi.indicator_code_name,
    bi.indicator_short_name,
    bi.dimension,
    bi.measurement_unit,
    bi.status,
    coalesce(us.total_implementations, 0) as total_implementations,
    coalesce(us.total_organizations_using, 0) as total_organizations_using,
    coalesce(rs.total_responses, 0) as total_responses,
    case
        when us.last_used_timestamp is not null
        then to_timestamp(us.last_used_timestamp)::date
        else null
    end as last_used_date
from base_indicators bi
left join usage_stats us
    on bi.indicator_template_id = us.indicator_template_id
left join response_stats rs
    on bi.indicator_template_id = rs.indicator_template_id
where
    bi.status = 'active'
    or us.last_used_timestamp > extract(epoch from current_date - interval '12 months')