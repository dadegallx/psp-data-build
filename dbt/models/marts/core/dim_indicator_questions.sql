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

-- Pivot color criteria from rows to columns
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

-- Add English display names to indicator templates
indicator_templates_with_translations as (
    select
        ssi.indicator_template_id,
        ssi.dimension_id,
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
        -- Primary key
        survey_stoplight.survey_indicator_id,

        -- Survey context
        survey_stoplight.survey_definition_id,

        -- Dimension attributes
        survey_stoplight_dimension.dimension_id,
        dimension_trans.translation_text as dimension_name,
        survey_stoplight_dimension.dimension_is_active,

        -- Master indicator (template)
        indicator_templates_with_translations.indicator_template_id,
        indicator_templates_with_translations.indicator_name,
        indicator_templates_with_translations.indicator_description,

        -- Survey indicator (instance)
        survey_stoplight.indicator_code_name as survey_indicator_code_name,
        survey_stoplight.indicator_short_name as survey_indicator_short_name,
        survey_stoplight.indicator_question_text as survey_indicator_question_text,
        survey_stoplight.indicator_description as survey_indicator_description,
        survey_stoplight.indicator_definition,
        survey_stoplight.indicator_is_required as survey_indicator_is_required,
        survey_stoplight.order_number,

        -- Color criteria descriptions (what each poverty level means for this indicator)
        color_criteria_pivoted.red_criteria_description,
        color_criteria_pivoted.yellow_criteria_description,
        color_criteria_pivoted.green_criteria_description,

        -- Audit fields (dimension)
        survey_stoplight_dimension.dimension_created_at,
        survey_stoplight_dimension.dimension_updated_at,

        -- Audit fields (survey indicator)
        survey_stoplight.survey_indicator_created_at,
        survey_stoplight.survey_indicator_updated_at

    from survey_stoplight
    inner join indicator_templates_with_translations
        on survey_stoplight.indicator_template_id = indicator_templates_with_translations.indicator_template_id
    left join survey_stoplight_dimension
        on survey_stoplight.survey_dimension_id = survey_stoplight_dimension.dimension_id
    left join translations dimension_trans
        on survey_stoplight_dimension.dimension_met_name = dimension_trans.translation_key
    left join color_criteria_pivoted
        on survey_stoplight.survey_indicator_id = color_criteria_pivoted.survey_indicator_id
)

select * from joined
