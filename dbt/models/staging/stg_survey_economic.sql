{{
  config(
    materialized='view',
    tags=['staging', 'economic']
  )
}}

with source as (
    select * from {{ source('data_collect', 'survey_economic') }}
),

renamed as (
    select
        -- Primary key
        id as survey_economic_id,

        -- Foreign keys
        survey_definition_id,

        -- Question identifiers
        code_name,
        question_text,

        -- Answer configuration
        answer_type,
        answer_options,

        -- Scope information
        scope,
        for_family_member as is_for_family_member,

        -- Audit fields
        created_date,
        last_modified_date

    from source
)

select * from renamed
