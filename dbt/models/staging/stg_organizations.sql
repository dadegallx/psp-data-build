with source as (
    select * from {{ source('ps_network', 'organizations') }}
),

renamed as (
    select
        -- Primary key
        id as organization_id,

        -- Foreign keys
        application_id,

        -- Attributes
        name as organization_name,
        description as organization_description,
        is_active as organization_is_active,
        country_code,
        language,

        -- Audit fields
        created_date as organization_created_at,
        last_modified_date as organization_updated_at

    from source
)

select * from renamed
