with source as (
    select * from {{ source('data_collect', 'snapshot_stoplight_achievement') }}
),

renamed as (
    select
        -- Primary key
        id as snapshot_stoplight_achievement_id,

        -- Foreign keys
        snapshot_stoplight_id,

        -- Attributes
        action,
        roadmap,

        -- Metadata
        created_by,
        last_modified_by,
        created_date,
        last_modified_date

    from source
)

select * from renamed
