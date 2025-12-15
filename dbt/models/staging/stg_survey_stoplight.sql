with source as (
    select * from {{ source('data_collect', 'survey_stoplight') }}
),

-- Deduplicate indicators per survey (fixing issue with survey_definition_id=80/socialcapital)
-- Keeps the most recently updated version of any duplicate indicator code within a survey
renamed as (
    select distinct on (survey_definition_id, lower(trim(code_name)))
        -- Primary key (survey-specific indicator ID)
        id as survey_indicator_id,

        -- Foreign keys
        survey_definition_id,
        survey_indicator_id as indicator_template_id,
        survey_dimension_id,

        -- Attributes (normalized for joins)
        lower(trim(code_name)) as indicator_code_name,
        short_name as indicator_short_name,
        question_text as indicator_question_text,
        description as indicator_description,
        definition as indicator_definition,
        required as indicator_is_required,
        order_number,

        -- Audit fields
        created_at as survey_indicator_created_at,
        updated_at as survey_indicator_updated_at

    from source
    order by
        survey_definition_id,
        lower(trim(code_name)),
        updated_at desc
)

select * from renamed
