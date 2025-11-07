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
        -- Survey-specific indicator (instance)
        survey_stoplight.indicator_id as survey_indicator_id,
        survey_stoplight.indicator_code_name as survey_indicator_code_name,
        survey_stoplight.indicator_short_name as survey_indicator_short_name,
        survey_stoplight.indicator_question_text as survey_indicator_question_text,
        survey_stoplight.indicator_description as survey_indicator_description,
        survey_stoplight.indicator_is_required as survey_indicator_is_required,
        survey_stoplight.dimension_name as survey_dimension_name,

        -- Master indicator (template) - for aggregation
        survey_stoplight_indicator.indicator_template_id as indicator_id,
        survey_stoplight_indicator.indicator_template_code_name as indicator_code_name,
        survey_stoplight_indicator.indicator_name as indicator_name,
        survey_stoplight_indicator.indicator_description as indicator_description,

        -- Dimension attributes
        survey_stoplight_indicator.dimension_id

    from survey_stoplight
    left join survey_stoplight_indicator
        on survey_stoplight.indicator_template_id = survey_stoplight_indicator.indicator_template_id
),

final as (
    select
        -- Surrogate key (based on survey-specific indicator ID)
        {{ dbt_utils.generate_surrogate_key(['survey_indicator_id']) }} as indicator_key,

        -- Natural keys
        survey_indicator_id,  -- Survey-specific ID
        indicator_id,         -- Master template ID

        -- MASTER INDICATOR ATTRIBUTES (for aggregation/grouping)
        indicator_code_name,      -- Template code (e.g., 'income')
        indicator_name,           -- English display name (e.g., 'Income')
        indicator_description,    -- English description

        -- SURVEY INDICATOR ATTRIBUTES (for localization/drill-down)
        survey_indicator_code_name,     -- Survey-specific code
        survey_indicator_short_name,    -- Translated name (e.g., 'Ingresos')
        survey_indicator_question_text, -- Translated question
        survey_indicator_description,   -- Translated description
        survey_indicator_is_required,   -- Required flag

        -- DIMENSION ATTRIBUTES
        dimension_id,
        survey_dimension_name as dimension_name,
        null as dimension_code  -- Not available in source

    from joined
)

select * from final
