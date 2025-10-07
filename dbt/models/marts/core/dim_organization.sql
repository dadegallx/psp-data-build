{{ config(
    materialized="view",
    tags=["mart", "dimension", "semantic_layer"]
) }}

with organizations as (
    select * from {{ ref('stg_organization') }}
),

final as (
    select
        -- Primary key
        organization_id,

        -- Foreign keys
        application_id,

        -- Organization attributes
        organization_name,
        description,
        is_active,
        country,
        country_code,
        language,

        -- Organization type and metadata
        organization_type,
        area_expertise_type,
        final_user_type,

        -- Features and access
        solutions_access,
        projects_access,
        projects_required,
        solutions_allowed_facilitators,
        solutions_crud_facilitators,

        -- Contact and branding
        support_email,
        logo_url,
        footer_text,
        information,
        feature_flags,

        -- Audit fields
        created_by,
        last_modified_by,
        created_at_ts,
        last_modified_at_ts

    from organizations
)

select * from final
