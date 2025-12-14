with source as (
    select * from {{ source('ps_network', 'applications') }}
),

renamed as (
    select
        -- Primary key
        id as application_id,

        -- Attributes
        name as application_name,
        description as application_description,
        is_active as application_is_active,
        country_code,

        -- Audit fields
        created_date as application_created_at,
        last_modified_date as application_updated_at

    from source
)

select * from renamed
