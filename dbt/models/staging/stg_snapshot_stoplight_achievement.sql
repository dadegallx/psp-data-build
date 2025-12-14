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

        -- Audit fields
        created_date as achievement_created_at,
        last_modified_date as achievement_updated_at

    from source
)

select * from renamed
