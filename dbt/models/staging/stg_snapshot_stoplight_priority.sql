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
        estimated_date, -- Represents months to improve? verify vs schema descriptions or dates. Schema says "Months to improve" but type is bigint? or timestamp? RAW_SCHEMA says "Months to improve" but type bigint. Let's keep as is for now.

        -- Metadata
        created_at,
        created_by,
        last_modified_by,
        created_date,
        last_modified_date

    from source
)

select * from renamed
