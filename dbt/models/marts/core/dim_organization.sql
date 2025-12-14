with organizations as (
    select * from {{ ref('stg_organizations') }}
),

applications as (
    select * from {{ ref('stg_applications') }}
),

joined as (
    select
        organizations.organization_id,
        organizations.organization_name,
        organizations.organization_description,
        organizations.organization_is_active,
        organizations.country_code as organization_country_code,

        -- Application hierarchy (denormalized)
        applications.application_id,
        applications.application_name,
        applications.application_description,
        applications.application_is_active,
        applications.country_code as application_country_code

    from organizations
    inner join applications
        on organizations.application_id = applications.application_id
),

final as (
    select
        -- Primary key
        organization_id,

        -- Organization attributes
        organization_name,
        organization_description,
        organization_is_active,
        organization_country_code,

        -- Application hierarchy (denormalized)
        application_id,
        application_name,
        application_description,
        application_is_active,
        application_country_code

    from joined
)

select * from final
