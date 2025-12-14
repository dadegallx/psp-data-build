with families as (
    select * from {{ ref('stg_families') }}
),

countries as (
    select * from {{ ref('stg_countries') }}
),

joined as (
    select
        -- Primary key
        families.family_id,

        -- Hub context
        families.application_id,

        -- Organization context
        families.organization_id,

        -- Project context
        families.project_id,

        -- Family attributes
        families.is_anonymous,
        families.family_is_active,
        countries.country_code,
        countries.country_name,
        families.latitude,
        families.longitude,

        -- Audit fields
        families.family_created_at,
        families.family_updated_at

    from families
    left join countries
        on families.country_id = countries.country_id
)

select * from joined
