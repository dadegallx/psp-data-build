{{
  config(
    materialized='table',
    tags=['mart', 'dimension', 'survey']
  )
}}

with survey_definitions as (
    select * from {{ ref('stg_survey_definitions') }}
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['survey_definition_id']) }} as survey_definition_key,

        -- Natural key
        survey_definition_id,

        -- Survey attributes
        survey_code,
        survey_title,
        survey_description,
        survey_language,
        survey_is_active,

        -- Additional attributes (not in source, set to defaults)
        null as survey_country_code,
        null as survey_status,
        false as survey_is_current

    from survey_definitions
)

select * from final
