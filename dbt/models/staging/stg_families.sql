with source as (
    select * from {{ source('ps_families', 'family') }}
),

renamed as (
    select
        -- Primary key
        family_id,

        -- Attributes
        is_active as family_is_active,
        anonymous as is_anonymous,
        country,
        organization_id,

        -- Geographic coordinates: validate format, range, and round to 2 decimals for privacy
        case
            when latitude ~ '^-?[0-9]+\.?[0-9]*$'
                and latitude::numeric between -90 and 90
            then round(latitude::numeric, 2)
        end as latitude,
        case
            when longitude ~ '^-?[0-9]+\.?[0-9]*$'
                and longitude::numeric between -180 and 180
            then round(longitude::numeric, 2)
        end as longitude

    from source
)

select * from renamed
