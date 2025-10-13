{{ config(
    materialized="view",
    tags=["staging", "dimension"]
) }}

with source as (
    {% if target.name in ['heroes-dev', 'heroes-prod'] %}
        select * from {{ source('heroes_network', 'heroes_organizations') }}
    {% else %}
        select * from {{ source('ps_network', 'organizations') }}
    {% endif %}
),

renamed as (
    select
        -- Primary key
        id as organization_id,

        -- Foreign keys
        application_id,

        -- Organization attributes
        name as organization_name,
        description,
        coalesce(is_active, true) as is_active,
        {% if target.name in ['heroes-dev', 'heroes-prod'] %}
            null as country,  -- Not in heroes
        {% else %}
            country,
        {% endif %}
        country_code,
        language,

        -- Organization type and metadata
        {% if target.name in ['heroes-dev', 'heroes-prod'] %}
            null as organization_type,
            null as area_expertise_type,
            null as final_user_type,

            -- Features and access (not in heroes)
            null as solutions_access,
            false as projects_access,
            false as projects_required,
            false as solutions_allowed_facilitators,
            false as solutions_crud_facilitators,

            -- Contact and branding (not in heroes)
            null as support_email,
            null::jsonb as logo_url,
            null as footer_text,
            null as information,
            null::jsonb as feature_flags,
        {% else %}
            organization_type,
            area_expertise_type,
            final_user_type,

            -- Features and access
            solutions_access,
            coalesce(projects_access, false) as projects_access,
            coalesce(projects_required, false) as projects_required,
            coalesce(solutions_allowed_facilitators, false) as solutions_allowed_facilitators,
            coalesce(solutions_crud_facilitators, false) as solutions_crud_facilitators,

            -- Contact and branding
            support_email,
            logo_url,
            footer_text,
            information,
            feature_flags,
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
