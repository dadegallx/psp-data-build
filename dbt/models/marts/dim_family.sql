with families as (
    select * from {{ ref('stg_families') }}
),

family_members as (
    select * from {{ ref('stg_family_members') }}
),

-- Get country from first family member with birth_country
family_countries as (
    select
        family_id,
        first_value(birth_country) over (
            partition by family_id
            order by created_at
        ) as country_code
    from family_members
    where birth_country is not null
),

-- Deduplicate to one row per family
family_countries_deduped as (
    select distinct
        family_id,
        country_code
    from family_countries
),

joined as (
    select
        families.family_id,
        families.family_code,
        families.family_name,
        families.family_is_active,
        families.is_anonymous,

        -- Geographic attributes
        family_countries_deduped.country_code,
        null as country,  -- Not available, would need country lookup table
        families.latitude,
        families.longitude,
        families.address,
        families.post_code

    from families
    left join family_countries_deduped
        on families.family_id = family_countries_deduped.family_id
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['family_id']) }} as family_key,

        -- Natural key
        family_id,

        -- Family attributes
        family_code,
        family_name,
        family_is_active,
        is_anonymous,

        -- Geographic attributes
        country,
        country_code,
        latitude,
        longitude,
        address,
        post_code

    from joined
)

select * from final
