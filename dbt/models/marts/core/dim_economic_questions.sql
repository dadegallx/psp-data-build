with survey_economic as (
    select * from {{ ref('stg_survey_economic') }}
),

survey_definitions as (
    select * from {{ ref('stg_survey_definitions') }}
),

final as (
    select
        -- Primary key
        se.survey_economic_id,

        -- Survey context (denormalized)
        se.survey_definition_id,
        sd.survey_code,
        sd.survey_title,
        sd.survey_description,
        sd.survey_language,
        sd.survey_is_active,

        -- Question attributes
        se.code_name,
        se.question_text,
        se.answer_type,
        se.answer_options,
        se.scope,
        se.topic,
        se.is_for_family_member,

        -- Audit fields (survey context)
        sd.survey_created_at,
        sd.survey_updated_at,

        -- Audit fields (question)
        se.survey_economic_created_at,
        se.survey_economic_updated_at

    from survey_economic as se
    left join survey_definitions as sd
        on se.survey_definition_id = sd.survey_definition_id
)

select * from final
