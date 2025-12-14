with source as (
    select * from {{ source('data_collect', 'snapshot_stoplight_priority') }}
),

renamed as (
    select
        -- Primary key
        id as snapshot_stoplight_priority_id,

        -- Foreign keys
        snapshot_stoplight_id,

        -- Attributes
        reason,
        action,
        estimated_date,  -- Months to improve

        -- Audit fields
        created_date as created_at,
        last_modified_date as updated_at

    from source
)

select * from renamed
