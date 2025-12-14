with source as (
    select * from {{ source('data_collect', 'survey_economic') }}
),

renamed as (
    select
        -- Primary key
        id as survey_economic_id,

        -- Foreign keys
        survey_definition_id,

        -- Question identifiers (normalized for joins)
        lower(trim(code_name)) as code_name,
        question_text,

        -- Answer configuration
        case
            when answer_type = 'string' then 'text'
            else answer_type
        end as answer_type,
        answer_options,

        -- Scope information
        scope,
        for_family_member as is_for_family_member,
        topic,

        -- Audit fields
        created_at as survey_economic_created_at,
        updated_at as survey_economic_updated_at

    from source
)

select * from renamed
