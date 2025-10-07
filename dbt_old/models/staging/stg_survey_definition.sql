select
    id,
    title,
    lang,
    active,
    survey_code

from {{ source('data_collect', 'survey_definition') }}