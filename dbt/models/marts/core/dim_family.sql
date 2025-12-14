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

        -- Family attributes
        families.is_anonymous,
        families.organization_id,

        -- Geographic attributes (resolved via country FK)
        countries.country_code,
        countries.country_name,
        families.latitude,
        families.longitude

    from families
    left join countries
        on families.country_id = countries.country_id
)

select * from joined
