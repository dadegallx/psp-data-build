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

        -- Geographic attributes
        latitude::decimal(10,7) as latitude,
        longitude::decimal(10,7) as longitude,
        address,
        post_code,

        -- Audit fields
        to_timestamp(created_at / 1000) as created_at,
        to_timestamp(updated_at / 1000) as updated_at

    from source
)

select * from renamed
