select
    definition_id,
    code_name,
    short_name,
    definition,
    dimension,
    survey_definition_id,
    indicator_master_id,

    -- Add window functions to handle duplicates
    row_number() over (
        partition by survey_definition_id, code_name
        order by definition_id
    ) as definition_rank,

    count(*) over (
        partition by survey_definition_id, code_name
    ) as definition_count

from {{ ref('stg_survey_stoplight') }}