{{
  config(
    materialized='view',
    tags=['staging']
  )
}}

with source as (
    select * from {{ source('ps_families', 'family') }}
),

renamed as (
    select
        -- Primary key
        family_id,

        -- Attributes
        code as family_code,
        case
            when anonymous then 'ANON_DATA'
            else name
        end as family_name,
        is_active as family_is_active,
        anonymous as is_anonymous,

        -- Geographic attributes (raw values for validation)
        latitude::decimal(10,7) as latitude_raw,
        longitude::decimal(10,7) as longitude_raw,
        address,
        post_code,

        -- Audit fields
        created_date as created_at,
        last_modified_date as updated_at

    from source
),

cleaned_coordinates as (
    select
        *,

        -- Validate and clean latitude (-90 to 90 degrees)
        case
            when latitude_raw IS NOT NULL
                AND (latitude_raw < -90 OR latitude_raw > 90)
            then NULL
            else latitude_raw
        end as latitude,

        -- Validate and clean longitude (-180 to 180 degrees)
        case
            when longitude_raw IS NOT NULL
                AND (longitude_raw < -180 OR longitude_raw > 180)
            then NULL
            else longitude_raw
        end as longitude,

        -- Data quality flag for monitoring
        case
            when (latitude_raw IS NOT NULL AND (latitude_raw < -90 OR latitude_raw > 90))
                OR (longitude_raw IS NOT NULL AND (longitude_raw < -180 OR longitude_raw > 180))
            then true
            else false
        end as has_invalid_coordinates

    from renamed
)

select
    -- Primary key
    family_id,

    -- Attributes
    family_code,
    family_name,
    family_is_active,
    is_anonymous,

    -- Geographic attributes (cleaned versions)
    latitude,
    longitude,
    address,
    post_code,

    -- Data quality flag
    has_invalid_coordinates,

    -- Audit fields
    created_at,
    updated_at

from cleaned_coordinates
