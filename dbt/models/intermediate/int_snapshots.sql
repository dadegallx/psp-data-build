{{
    config(
        materialized='table',
        schema='staging',
        tags=['intermediate']
    )
}}

with snapshots as (
    select * from {{ ref('stg_snapshots') }}
),

-- First compute snapshot_number (needed for max_snapshot_number calculation)
with_snapshot_number as (
    select
        snapshot_id,
        family_id,
        organization_id,
        application_id,
        survey_definition_id,
        project_id,
        is_anonymous,
        stoplight_skipped,
        snapshot_date,
        created_at,
        created_by,
        updated_at,

        -- Re-compute snapshot_number chronologically per family+survey
        -- Fixes source data integrity issues where baseline has later date than follow-up
        row_number() over (
            partition by family_id, survey_definition_id
            order by snapshot_date, created_at, snapshot_id
        ) as snapshot_number
    from snapshots
),

final as (
    select
        -- Primary key
        snapshot_id,

        -- Foreign keys
        family_id,
        organization_id,
        application_id,
        survey_definition_id,
        project_id,

        -- Attributes
        is_anonymous,
        stoplight_skipped,

        -- Date fields
        snapshot_date,
        created_at,

        -- Audit fields
        created_by,
        updated_at,

        -- Snapshot sequencing
        snapshot_number,

        -- Is this the family's most recent snapshot (across all surveys)?
        case
            when row_number() over (
                partition by family_id
                order by snapshot_date desc, created_at desc, snapshot_id desc
            ) = 1
            then true
            else false
        end as is_last,

        -- Max snapshot number in this family+survey journey (for cohort filtering)
        max(snapshot_number) over (
            partition by family_id, survey_definition_id
        ) as max_snapshot_number

    from with_snapshot_number
)

select * from final
