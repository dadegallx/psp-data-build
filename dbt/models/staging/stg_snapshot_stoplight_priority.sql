with source as (
    select * from {{ source('data_collect', 'snapshot_stoplight_priority') }}
),

-- Deduplicate: keep one priority per snapshot_stoplight_id (earliest by id)
deduplicated as (
    select
        *,
        row_number() over (
            partition by snapshot_stoplight_id
            order by id
        ) as row_num
    from source
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
        created_date as priority_created_at,
        last_modified_date as priority_updated_at

    from deduplicated
    where row_num = 1
)

select * from renamed
