with survey_definitions as (
    select * from {{ ref('stg_survey_definitions') }}
),

final as (
    select
        -- Primary key
        survey_definition_id,

        -- Survey attributes
        survey_code,
        survey_title,
        survey_description,
        survey_language,
        survey_is_active,
        country_code as survey_country_code,

        -- Audit fields
        survey_created_at,
        survey_updated_at

    from survey_definitions
)

select * from final
