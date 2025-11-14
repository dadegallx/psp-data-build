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

survey_stoplight_color as (
    select * from {{ ref('stg_survey_stoplight_color') }}
),

survey_stoplight_dimension as (
    select * from {{ source('data_collect', 'survey_stoplight_dimension') }}
),

translations as (
    select * from {{ ref('stg_translations') }}
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

        -- Master indicator (template) - for aggregation
        survey_stoplight_indicator.indicator_template_id as indicator_id,
        survey_stoplight_indicator.indicator_template_code_name as indicator_code_name,
        survey_stoplight_indicator.indicator_name as indicator_name,
        survey_stoplight_indicator.indicator_description as indicator_description,

        -- Dimension attributes (from master dimension table with English translation)
        survey_stoplight_indicator.dimension_id,
        translations.translation_text as dimension_name,

        -- Color criteria descriptions (what each color level means)
        survey_stoplight_color.red_criteria_description,
        survey_stoplight_color.yellow_criteria_description,
        survey_stoplight_color.green_criteria_description

    from survey_stoplight
    left join survey_stoplight_indicator
        on survey_stoplight.indicator_template_id = survey_stoplight_indicator.indicator_template_id
    left join survey_stoplight_dimension
        on survey_stoplight_indicator.dimension_id = survey_stoplight_dimension.id
    left join translations
        on survey_stoplight_dimension.met_name = translations.translation_key
    left join survey_stoplight_color
        on survey_stoplight.indicator_id = survey_stoplight_color.survey_indicator_id
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
        dimension_name,  -- English canonical name from translation table
        null as dimension_code,  -- Not available in source

        -- COLOR CRITERIA DESCRIPTIONS (what each poverty level means for this indicator)
        red_criteria_description,      -- Critical poverty threshold description
        yellow_criteria_description,   -- Moderate poverty threshold description
        green_criteria_description     -- Non-poor threshold description

    from joined
)

select * from final
