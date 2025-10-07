{{ config(
    materialized="view",
    tags=["mart", "dimension", "semantic_layer"]
) }}

with survey_defs as (
    select * from {{ ref('stg_survey_definition') }}
),

final as (
    select
        -- Primary key
        survey_definition_id,

        -- Survey metadata
        survey_title,
        survey_description,
        survey_code,
        stoplight_type,
        status,
        language,

        -- Flags
        is_active,
        is_current,
        disclaimer_required,

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

    from survey_defs
)

select * from final
