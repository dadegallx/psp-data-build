{{ config(
    materialized="view",
    tags=["staging", "dimension"]
) }}

with source as (
    select * from {{ source('ps_families', 'family') }}
),

renamed as (
    select
        -- Primary key
        family_id,

        -- Foreign keys
        organization_id,
        application_id,
        project_id,
        user_id,

        -- Family attributes (privacy-aware)
        name as family_name,
        code as family_code,
        coalesce(anonymous, false) as is_anonymous,
        coalesce(is_active, true) as is_active,

        -- Location data
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
        to_timestamp(extract(epoch from created_date)) as created_at_ts,
        to_timestamp(extract(epoch from last_modified_date)) as last_modified_at_ts,

        -- Legacy
        legacy_family_code

    from source
)

select * from renamed
