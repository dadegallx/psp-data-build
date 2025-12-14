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

        -- Re-compute snapshot_number chronologically per family+survey
        -- Fixes source data integrity issues where baseline has later date than follow-up
        row_number() over (
            partition by family_id, survey_definition_id
            order by snapshot_date, created_at, snapshot_id
        ) as snapshot_number,

        -- Calculate is_last dynamically to fix data integrity issues in source
        case
            when row_number() over (
                partition by family_id
                order by snapshot_date desc, created_at desc, snapshot_id desc
            ) = 1
            then true
            else false
        end as is_last,

        -- Max wave reached by this family (for cohort/survivor curve filtering)
        count(*) over (
            partition by family_id
        ) as max_wave_reached

    from snapshots
)

select * from final
