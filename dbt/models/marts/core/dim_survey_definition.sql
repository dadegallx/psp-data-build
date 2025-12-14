with survey_definitions as (
    select * from {{ ref('stg_survey_definitions') }}
),

countries as (
    select * from {{ ref('stg_countries') }}
),

joined as (
    select
        -- Primary key
        survey_definitions.survey_definition_id,

        -- Survey attributes
        survey_definitions.survey_code,
        survey_definitions.survey_title,
        survey_definitions.survey_description,
        survey_definitions.survey_language,
        survey_definitions.survey_is_active,
        countries.country_code as survey_country_code,
        countries.country_name as survey_country_name,

        -- Audit fields
        survey_definitions.survey_created_at,
        survey_definitions.survey_updated_at

    from survey_definitions
    left join countries
        on survey_definitions.country_code = countries.country_code
)

select * from joined
