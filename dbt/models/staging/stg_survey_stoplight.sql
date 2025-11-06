{{
  config(
    materialized='view',
    tags=['staging']
  )
}}

with source as (
    select * from {{ source('data_collect', 'survey_stoplight') }}
),

renamed as (
    select
        -- Primary key (this becomes indicator_id in dimension)
        id as indicator_id,

        -- Foreign keys
        survey_indicator_id as indicator_template_id,

        -- Attributes
        code_name as indicator_code_name,
        short_name as indicator_short_name,
        question_text as indicator_question_text,
        description as indicator_description,
        required as indicator_is_required,
        dimension as dimension_name  -- One of 6 poverty dimensions

    from source
)

select * from renamed
