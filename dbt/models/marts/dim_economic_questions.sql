{{
  config(
    materialized='table',
    tags=['mart', 'dimension', 'economic']
  )
}}

with survey_economic as (
    select * from {{ ref('stg_survey_economic') }}
),

survey_definitions as (
    select * from {{ ref('stg_survey_definitions') }}
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key([
            'se.survey_definition_id',
            'se.code_name'
        ]) }} as economic_question_key,

        -- Natural keys
        se.survey_definition_id,
        se.code_name,

        -- Question attributes
        se.question_text,
        se.answer_type,
        se.answer_options,
        se.scope,
        se.is_for_family_member,

        -- Survey context
        sd.survey_code,
        sd.survey_title,
        sd.survey_language,

        -- Audit fields
        se.created_date,
        se.last_modified_date

    from survey_economic as se
    left join survey_definitions as sd
        on se.survey_definition_id = sd.survey_definition_id
)

select * from final
