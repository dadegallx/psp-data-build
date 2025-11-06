{{
  config(
    materialized='view',
    tags=['staging']
  )
}}

with source as (
    select * from {{ source('ps_families', 'family_members') }}
),

renamed as (
    select
        -- Primary key
        family_member_id,

        -- Foreign keys
        family_id,

        -- Attributes (relevant for country derivation)
        birth_country,

        -- Audit fields
        to_timestamp(created_at / 1000) as created_at

    from source
)

select * from renamed
