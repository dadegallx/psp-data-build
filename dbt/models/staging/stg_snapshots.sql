{{
  config(
    materialized='view',
    tags=['staging']
  )
}}

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

        -- Attributes
        snapshot_number,
        is_last,
        anonymous,

        -- Date fields (convert from milliseconds to timestamp)
        to_timestamp(snapshot_date / 1000) as snapshot_date,
        to_timestamp(created_at / 1000) as created_at,

        -- Audit fields
        created_by,
        last_modified_date as updated_at

    from source
    where snapshot_date is not null  -- Filter out snapshots without dates
)

select * from renamed
