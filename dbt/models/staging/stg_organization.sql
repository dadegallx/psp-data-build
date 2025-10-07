{{ config(
    materialized="view",
    tags=["staging", "dimension"]
) }}

with source as (
    select * from {{ source('ps_network', 'organizations') }}
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
        country,
        country_code,
        language,

        -- Organization type and metadata
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

        -- Audit fields
        created_by,
        last_modified_by,
        to_timestamp(extract(epoch from created_date)) as created_at_ts,
        to_timestamp(extract(epoch from last_modified_date)) as last_modified_at_ts

    from source
)

select * from renamed
