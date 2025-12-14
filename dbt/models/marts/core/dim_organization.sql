with organizations as (
    select * from {{ ref('stg_organizations') }}
),

applications as (
    select * from {{ ref('stg_applications') }}
),

countries as (
    select * from {{ ref('stg_countries') }}
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
        app_country.country_code as application_country_code,
        app_country.country_name as application_country_name,
        applications.application_created_at,
        applications.application_updated_at,

        -- Organization attributes
        organizations.organization_name,
        organizations.organization_description,
        organizations.organization_is_active,
        org_country.country_code as organization_country_code,
        org_country.country_name as organization_country_name,
        organizations.language as organization_language,

        -- Audit fields
        organizations.organization_created_at,
        organizations.organization_updated_at

    from organizations
    inner join applications
        on organizations.application_id = applications.application_id
    left join countries as org_country
        on organizations.country_code = org_country.country_code
    left join countries as app_country
        on applications.country_code = app_country.country_code
)

select * from joined
