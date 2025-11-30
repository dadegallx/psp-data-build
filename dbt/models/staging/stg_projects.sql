with source as (
    select * from {{ source('ps_network', 'projects') }}
),

renamed as (
    select
        -- Primary key
        id as project_id,

        -- Foreign keys
        organization_id,

        -- Attributes
        title as project_name,
        description as project_description,
        active as is_active,

        -- Date range
        from_date,
        to_date,

        -- Audit fields
        created_at

    from source
)

select * from renamed
