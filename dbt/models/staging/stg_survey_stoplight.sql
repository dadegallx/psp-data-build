select
    id as definition_id,
    code_name,
    short_name,
    definition,
    dimension,
    survey_definition_id,
    survey_indicator_id as indicator_master_id

from {{ source('data_collect', 'survey_stoplight') }}