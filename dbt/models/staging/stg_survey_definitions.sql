with source as (
    select * from {{ source('data_collect', 'survey_definition') }}
),

renamed as (
    select
        -- Primary key
        id as survey_definition_id,

        -- Attributes
        survey_code,
        title as survey_title,
        description as survey_description,
        lang as survey_language,
        active as survey_is_active,
        country_code,

        -- Audit fields
        created_at as survey_created_at,
        updated_at as survey_updated_at

    from source
)

select * from renamed
