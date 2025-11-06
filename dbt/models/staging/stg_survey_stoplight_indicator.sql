{{
  config(
    materialized='view',
    tags=['staging']
  )
}}

with source as (
    select * from {{ source('data_collect', 'survey_stoplight_indicator') }}
),

renamed as (
    select
        -- Primary key
        id as indicator_template_id,

        -- Attributes
        code_name as indicator_template_code_name,
        met_short_name as indicator_template_short_name,
        met_description as indicator_template_description,

        -- Foreign keys
        survey_dimension_id as dimension_id

    from source
)

select * from renamed
