{{ config(
    materialized="view",
    tags=["mart", "dimension", "semantic_layer"]
) }}

with applications as (
    select * from {{ ref('stg_application') }}
),

final as (
    select
        -- Primary key
        application_id,

        -- Application attributes
        application_name,
        description,
        is_active,
        country,
        country_code,
        language,

        -- Partner information
        partner_type,

        -- Branding
        logo_url,
        labels,

        -- Audit fields
        created_by,
        last_modified_by,
        created_at_ts,
        last_modified_at_ts

    from applications
)

select * from final
