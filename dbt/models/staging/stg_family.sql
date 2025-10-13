{{ config(
    materialized="view",
    tags=["staging", "dimension"]
) }}

with source as (
    {% if target.name in ['heroes-dev', 'heroes-prod'] %}
        select * from {{ source('heroes_families', 'heroes_family') }}
    {% else %}
        select * from {{ source('ps_families', 'family') }}
    {% endif %}
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
        {% if target.name in ['heroes-dev', 'heroes-prod'] %}
            null as family_name,  -- Not in heroes
        {% else %}
            name as family_name,
        {% endif %}
        code as family_code,
        coalesce(anonymous, false) as is_anonymous,
        coalesce(is_active, true) as is_active,

        -- Location data
        {% if target.name in ['heroes-dev', 'heroes-prod'] %}
            null as country,
        {% else %}
            country,
        {% endif %}
        longitude,
        latitude,
        {% if target.name in ['heroes-dev', 'heroes-prod'] %}
            null as accuracy,
            null as address,
            null as post_code,
        {% else %}
            accuracy,
            address,
            post_code,
        {% endif %}

        -- Metadata
        {% if target.name in ['heroes-dev', 'heroes-prod'] %}
            null::bigint as count_family_members,
            null as lifemap_url,
            null as profile_picture_url,
        {% else %}
            count_family_members,
            lifemap_url,
            profile_picture_url,
        {% endif %}

        -- Audit fields
        {% if target.name in ['heroes-dev', 'heroes-prod'] %}
            null as created_by,
            null as last_modified_by,
            created_date as created_at_ts,
            last_modified_date as last_modified_at_ts,

            null as legacy_family_code
        {% else %}
            created_by,
            last_modified_by,
            to_timestamp(extract(epoch from created_date)) as created_at_ts,
            to_timestamp(extract(epoch from last_modified_date)) as last_modified_at_ts,

            -- Legacy
            legacy_family_code
        {% endif %}

    from source
)

select * from renamed
