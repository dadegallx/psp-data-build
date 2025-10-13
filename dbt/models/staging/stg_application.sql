{{ config(
    materialized="view",
    tags=["staging", "dimension"]
) }}

with source as (
    {% if target.name in ['heroes-dev', 'heroes-prod'] %}
        select * from {{ source('heroes_network', 'heroes_applications') }}
    {% else %}
        select * from {{ source('ps_network', 'applications') }}
    {% endif %}
),

renamed as (
    select
        -- Primary key
        id as application_id,

        -- Application attributes
        name as application_name,
        description,
        coalesce(is_active, true) as is_active,
        country,
        country_code,
        language,

        -- Partner information
        partner_type,

        -- Branding
        {% if target.name in ['heroes-dev', 'heroes-prod'] %}
            null::jsonb as logo_url,  -- Not in heroes
            null::jsonb as labels,     -- Not in heroes
        {% else %}
            logo_url,
            labels,
        {% endif %}

        -- Audit fields
        {% if target.name in ['heroes-dev', 'heroes-prod'] %}
            null as created_by,
            null as last_modified_by,
            created_date as created_at_ts,
            last_modified_date as last_modified_at_ts
        {% else %}
            created_by,
            last_modified_by,
            to_timestamp(extract(epoch from created_date)) as created_at_ts,
            to_timestamp(extract(epoch from last_modified_date)) as last_modified_at_ts
        {% endif %}

    from source
)

select * from renamed
