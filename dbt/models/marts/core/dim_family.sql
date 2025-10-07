{{ config(
    materialized="view",
    tags=["mart", "dimension", "semantic_layer"]
) }}

with families as (
    select * from {{ ref('stg_family') }}
),

final as (
    select
        -- Primary key
        family_id,

        -- Foreign keys
        organization_id,
        application_id,
        project_id,
        user_id,

        -- Family attributes (privacy-aware: PII masked when is_anonymous=true)
        case
            when is_anonymous then 'ANON_DATA'
            else family_name
        end as family_name,

        family_code,
        is_anonymous,
        is_active,

        -- Location data (kept but may need masking in production)
        country,
        longitude,
        latitude,
        accuracy,
        address,
        post_code,

        -- Metadata
        count_family_members,
        lifemap_url,
        profile_picture_url,

        -- Audit fields
        created_by,
        last_modified_by,
        created_at_ts,
        last_modified_at_ts,

        -- Legacy
        legacy_family_code

    from families
)

select * from final
