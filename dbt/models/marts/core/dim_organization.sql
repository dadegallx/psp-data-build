with organizations as (
    select * from {{ ref('stg_organizations') }}
),

applications as (
    select * from {{ ref('stg_applications') }}
),

joined as (
    select
        -- Primary key
        organizations.organization_id,

        -- Hub context (denormalized)
        applications.application_id,
        applications.application_name,
        applications.application_description,
        applications.application_is_active,
        applications.country_code as application_country_code,
        applications.application_created_at,
        applications.application_updated_at,

        -- Organization attributes
        organizations.organization_name,
        organizations.organization_description,
        organizations.organization_is_active,
        organizations.country_code as organization_country_code,
        organizations.language as organization_language,

        -- Audit fields
        organizations.organization_created_at,
        organizations.organization_updated_at

    from organizations
    inner join applications
        on organizations.application_id = applications.application_id
)

select * from joined
