{{
  config(
    materialized='table',
    tags=['mart', 'dimension', 'indicator']
  )
}}

with survey_stoplight as (
    select * from {{ ref('stg_survey_stoplight') }}
),

survey_stoplight_indicator as (
    select * from {{ ref('stg_survey_stoplight_indicator') }}
),

joined as (
    select
        survey_stoplight.indicator_id,
        survey_stoplight.indicator_code_name,
        survey_stoplight.indicator_short_name,
        survey_stoplight.indicator_question_text,
        survey_stoplight.indicator_description,
        survey_stoplight.indicator_is_required,
        survey_stoplight.dimension_name,

        -- Template linkage
        survey_stoplight.indicator_template_id,
        survey_stoplight_indicator.indicator_template_code_name,

        -- Dimension attributes
        survey_stoplight_indicator.dimension_id

    from survey_stoplight
    left join survey_stoplight_indicator
        on survey_stoplight.indicator_template_id = survey_stoplight_indicator.indicator_template_id
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['indicator_id']) }} as indicator_key,

        -- Natural key
        indicator_id,

        -- Indicator attributes
        indicator_code_name,
        indicator_short_name,
        indicator_question_text,
        indicator_description,
        indicator_is_required,

        -- Dimension hierarchy (denormalized)
        dimension_id,
        dimension_name,
        null as dimension_code,  -- Not available in source

        -- Template linkage
        indicator_template_id,
        indicator_template_code_name

    from joined
)

select * from final
