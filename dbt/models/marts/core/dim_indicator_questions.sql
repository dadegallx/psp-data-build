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
    select * from {{ ref('stg_survey_stoplight_dimension') }}
),

translations as (
    select * from {{ ref('stg_translations') }}
),

-- Pivot color criteria from rows to columns (was in stg_survey_stoplight_color)
color_criteria_pivoted as (
    select
        survey_indicator_id,
        max(case when color_value = 1 then color_description end) as red_criteria_description,
        max(case when color_value = 2 then color_description end) as yellow_criteria_description,
        max(case when color_value = 3 then color_description end) as green_criteria_description
    from survey_stoplight_color
    where color_value in (1, 2, 3)
    group by survey_indicator_id
),

-- Add English display names to indicator templates (was in stg_survey_stoplight_indicator)
indicator_templates_with_translations as (
    select
        ssi.indicator_template_id,
        ssi.dimension_id,
        ssi.indicator_template_code_name,
        ssi.indicator_template_short_name,
        ssi.indicator_template_description,
        name_trans.translation_text as indicator_name,
        desc_trans.translation_text as indicator_description
    from survey_stoplight_indicator ssi
    left join translations name_trans
        on ssi.indicator_template_short_name = name_trans.translation_key
    left join translations desc_trans
        on ssi.indicator_template_description = desc_trans.translation_key
),

joined as (
    select
        -- Survey-specific indicator (instance)
        survey_stoplight.survey_indicator_id,
        survey_stoplight.indicator_code_name as survey_indicator_code_name,
        survey_stoplight.indicator_short_name as survey_indicator_short_name,
        survey_stoplight.indicator_question_text as survey_indicator_question_text,
        survey_stoplight.indicator_description as survey_indicator_description,
        survey_stoplight.indicator_is_required as survey_indicator_is_required,

        -- Master indicator (template) - for aggregation
        indicator_templates_with_translations.indicator_template_id,
        indicator_templates_with_translations.indicator_template_code_name as indicator_code_name,
        indicator_templates_with_translations.indicator_name as indicator_name,
        indicator_templates_with_translations.indicator_description as indicator_description,

        -- Dimension attributes (from master dimension table with English translation)
        indicator_templates_with_translations.dimension_id,
        dimension_trans.translation_text as dimension_name,
        survey_stoplight_dimension.dimension_code,

        -- Color criteria descriptions (what each color level means)
        color_criteria_pivoted.red_criteria_description,
        color_criteria_pivoted.yellow_criteria_description,
        color_criteria_pivoted.green_criteria_description

    from survey_stoplight
    inner join indicator_templates_with_translations
        on survey_stoplight.indicator_template_id = indicator_templates_with_translations.indicator_template_id
    left join survey_stoplight_dimension
        on indicator_templates_with_translations.dimension_id = survey_stoplight_dimension.dimension_id
    left join translations dimension_trans
        on survey_stoplight_dimension.dimension_met_name = dimension_trans.translation_key
    left join color_criteria_pivoted
        on survey_stoplight.survey_indicator_id = color_criteria_pivoted.survey_indicator_id
),

final as (
    select
        -- Primary key (survey-specific indicator ID)
        survey_indicator_id,
        indicator_template_id,    -- Master template ID

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
        dimension_code,  -- Dimension code (e.g., 'incomeAndEmployment')

        -- COLOR CRITERIA DESCRIPTIONS (what each poverty level means for this indicator)
        red_criteria_description,      -- Critical poverty threshold description
        yellow_criteria_description,   -- Moderate poverty threshold description
        green_criteria_description     -- Non-poor threshold description

    from joined
)

select * from final
