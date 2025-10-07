{{ config(
    materialized="view",
    tags=["staging", "snapshot"]
) }}

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
        project_id,

        -- Snapshot metadata
        snapshot_number,
        is_last,

        -- Timestamps (convert seconds epoch to timestamp)
        to_timestamp(snapshot_date) as snapshot_ts,
        to_timestamp(created_at / 1000.0) as created_at_ts,

        -- Flags
        coalesce(stoplight_skipped, false) as stoplight_skipped,
        coalesce(anonymous, false) as anonymous,

        -- User tracking
        created_by,
        last_modified_by,
        survey_user_id,

        -- JSON data (kept for future use)
        economic,
        stoplight,

        -- Other fields
        draft_id,
        sign,
        stoplight_client,
        lifemap_url

    from source
)

select * from renamed
