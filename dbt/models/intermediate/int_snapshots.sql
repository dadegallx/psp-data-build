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
        snapshot_created_at,
        created_by,
        snapshot_updated_at,

        -- Re-compute snapshot_number chronologically per family+survey
        -- Fixes source data integrity issues where baseline has later date than follow-up
        row_number() over (
            partition by family_id, survey_definition_id
            order by snapshot_date, snapshot_created_at, snapshot_id
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
        snapshot_created_at,

        -- Audit fields
        created_by,
        snapshot_updated_at,

        -- Snapshot sequencing
        snapshot_number,

        -- Is this the family's most recent snapshot (across all surveys)?
        case
            when row_number() over (
                partition by family_id
                order by snapshot_date desc, snapshot_created_at desc, snapshot_id desc
            ) = 1
            then true
            else false
        end as is_last,

        -- Baseline flag (snapshot_number = 1)
        snapshot_number = 1 as is_baseline,

        -- Days elapsed since baseline survey (0 for baseline, positive for follow-ups)
        snapshot_date::date - first_value(snapshot_date::date) over (
            partition by family_id, survey_definition_id
            order by snapshot_date, snapshot_created_at, snapshot_id
        ) as days_since_baseline,

        -- Days elapsed since previous snapshot (NULL for baseline)
        snapshot_date::date - lag(snapshot_date::date) over (
            partition by family_id, survey_definition_id
            order by snapshot_date, snapshot_created_at, snapshot_id
        ) as days_since_previous,

        -- Max snapshot number in this family+survey journey (for cohort filtering)
        max(snapshot_number) over (
            partition by family_id, survey_definition_id
        ) as max_snapshot_number

    from with_snapshot_number
)

select * from final
