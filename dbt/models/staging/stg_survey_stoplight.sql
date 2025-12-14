with source as (
    select * from {{ source('data_collect', 'survey_stoplight') }}
),

renamed as (
    select
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
)

select * from renamed
