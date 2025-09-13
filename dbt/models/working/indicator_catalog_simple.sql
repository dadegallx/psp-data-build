{{ config(materialized='view') }}

-- Simplified master list of all indicator templates
-- Grain: One row per indicator template

select
    ssi.id as indicator_template_id,
    ssi.code_name as indicator_code_name,
    ssi.met_short_name as indicator_short_name,
    ssd.met_name as dimension,
    null as measurement_unit,
    'active' as status,
    0 as total_implementations,
    0 as total_organizations_using,
    0 as total_responses,
    null::date as last_used_date
from {{ source('data_collect', 'survey_stoplight_indicator') }} ssi
left join {{ source('data_collect', 'survey_stoplight_dimension') }} ssd
    on ssi.survey_dimension_id = ssd.id