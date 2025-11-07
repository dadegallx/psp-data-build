{{
  config(
    materialized='view',
    tags=['staging']
  )
}}

with source as (
    select * from {{ source('data_collect', 'survey_stoplight_indicator') }}
),

translations as (
    select * from {{ ref('stg_translations') }}
),

renamed as (
    select
        -- Primary key
        source.id as indicator_template_id,

        -- Attributes
        source.code_name as indicator_template_code_name,
        source.met_short_name as indicator_template_short_name,
        source.met_description as indicator_template_description,

        -- Foreign keys
        source.survey_dimension_id as dimension_id

    from source
),

with_english_names as (
    select
        renamed.indicator_template_id,
        renamed.indicator_template_code_name,
        renamed.indicator_template_short_name,
        renamed.indicator_template_description,
        renamed.dimension_id,

        -- Add English display names from translation table
        name_translation.translation_text as indicator_name,
        desc_translation.translation_text as indicator_description

    from renamed
    left join translations as name_translation
        on renamed.indicator_template_short_name = name_translation.translation_key
    left join translations as desc_translation
        on renamed.indicator_template_description = desc_translation.translation_key
)

select * from with_english_names
