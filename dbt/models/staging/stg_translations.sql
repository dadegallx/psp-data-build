{{
  config(
    materialized='view',
    tags=['staging']
  )
}}

with source as (
    select * from {{ source('data_collect', 'translation') }}
),

english_only as (
    select
        -- Primary key
        id as translation_id,

        -- Translation key (e.g., 'income.name')
        key as translation_key,

        -- Language code
        lang as language_code,

        -- English translation text
        translation as translation_text

    from source
    where lang = 'EN'  -- Filter to English only for canonical names
)

select * from english_only
