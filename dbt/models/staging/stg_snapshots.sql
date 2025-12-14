with source as (
    select * from {{ source('data_collect', 'snapshot') }}
),

renamed as (
    select
        -- Primary key
        id as snapshot_id,

        -- Foreign keys
        family_id,
        organization_id,
        application_id,
        survey_definition_id,
        project_id,  -- Nullable: not all snapshots have a project

        -- Attributes
        snapshot_number,
        is_last,
        anonymous as is_anonymous,
        stoplight_skipped,

        -- Date fields (stored in seconds, convert to timestamp)
        to_timestamp(snapshot_date) as snapshot_date,

        -- Audit fields
        to_timestamp(created_at) as snapshot_created_at,
        last_modified_date as snapshot_updated_at

    from source
)

select * from renamed
