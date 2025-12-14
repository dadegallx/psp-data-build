with source as (
    select * from {{ source('system', 'countries') }}
),

renamed as (
    select
        -- Primary key
        id as country_id,

        -- Attributes (trimmed to remove trailing spaces from char fields)
        trim(alfa_2_code) as country_code,
        country as country_name

    from source
)

select * from renamed
