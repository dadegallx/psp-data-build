{{ config(
    materialized="view",
    tags=["staging", "dimension"]
) }}

with source as (
    select * from {{ source('data_collect', 'survey_definition') }}
),

renamed as (
    select
        -- Primary key
        id as survey_definition_id,

        -- Survey metadata
        title as survey_title,
        description as survey_description,
        survey_code,
        stoplight_type,
        status,
        lang as language,

        -- Flags
        coalesce(active, false) as is_active,
        coalesce(current, false) as is_current,
        coalesce(disclaimer_required, false) as disclaimer_required,

        -- Configuration
        minimum_priorities,
        country_code,
        latitude,
        longitude,
        labels,

        -- Disclaimer content
        disclaimer_text,
        disclaimer_title,
        disclaimer_subtitle,

        -- References
        terms_conditions_id,
        privacy_policy_id,

        -- Timestamps
        created_at,
        updated_at

    from source
)

select * from renamed
