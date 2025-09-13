{{ config(materialized='view') }}

-- Track which organizations use which indicator templates
-- Grain: One row per indicator template per organization

with organization_indicator_usage as (
    select
        s.organization_id,
        ssi.id as indicator_template_id,
        ssi.code_name as indicator_code_name,
        ssi.met_short_name as indicator_short_name,
        ss.dimension,
        count(distinct ss.id) as surveys_using_indicator,
        max(extract(epoch from sd.created_at)) as last_measurement_timestamp
    from {{ source('data_collect', 'survey_definition') }} sd
    inner join {{ source('data_collect', 'survey_stoplight') }} ss
        on sd.id = ss.survey_definition_id
    inner join {{ source('data_collect', 'survey_stoplight_indicator') }} ssi
        on ss.survey_indicator_id = ssi.id
    inner join {{ source('data_collect', 'snapshot') }} s
        on sd.id = s.survey_definition_id
    group by
        s.organization_id,
        ssi.id,
        ssi.code_name,
        ssi.met_short_name,
        ss.dimension
),

family_counts as (
    select
        s.organization_id,
        ssi.id as indicator_template_id,
        count(distinct s.family_id) as families_measured
    from {{ source('data_collect', 'survey_definition') }} sd
    inner join {{ source('data_collect', 'survey_stoplight') }} ss
        on sd.id = ss.survey_definition_id
    inner join {{ source('data_collect', 'survey_stoplight_indicator') }} ssi
        on ss.survey_indicator_id = ssi.id
    inner join {{ source('data_collect', 'snapshot') }} s
        on sd.id = s.survey_definition_id
    inner join {{ source('data_collect', 'snapshot_stoplight') }} sns
        on s.id = sns.snapshot_id
        and ss.code_name = sns.code_name
    group by
        s.organization_id,
        ssi.id
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
    oiu.organization_id,
    oiu.indicator_template_id,
    od.organization_name,
    od.hub_name,
    od.country,
    oiu.indicator_code_name,
    oiu.indicator_short_name,
    oiu.dimension,
    oiu.surveys_using_indicator,
    coalesce(fc.families_measured, 0) as families_measured,
    case
        when oiu.last_measurement_timestamp is not null
        then to_timestamp(oiu.last_measurement_timestamp)::date
        else null
    end as last_measurement_date,
    case
        when oiu.last_measurement_timestamp > extract(epoch from current_date - interval '90 days')
        then true
        else false
    end as is_currently_active
from organization_indicator_usage oiu
left join family_counts fc
    on oiu.organization_id = fc.organization_id
    and oiu.indicator_template_id = fc.indicator_template_id
left join organization_details od
    on oiu.organization_id = od.organization_id