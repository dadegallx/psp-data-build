{{
    config(
        materialized='table',
        tags=['mart', 'semantic_layer']
    )
}}

{#
    SNAPSHOT FACT TABLE

    Grain: One row per family × snapshot

    This table captures the snapshot-level attributes for each family survey event.
    Join to fact_indicators via snapshot_id for indicator-level analysis.

    Key columns:
    - snapshot_number: Sequential survey number (1=baseline, 2+=followup)
    - is_baseline: TRUE if this is the first survey for this family+survey_definition
    - is_last: TRUE if this is the family's most recent snapshot (across all surveys)
    - days_since_baseline: Days elapsed since baseline (0 for baseline)
    - days_since_previous: Days since prior snapshot (NULL for baseline)

    Use Cases:
    - Cohort analysis: Filter by max_snapshot_number to find families with N+ surveys
    - Time-to-followup: Analyze days_since_baseline distribution
    - Current status: Filter WHERE is_last = TRUE for most recent family state
#}

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

        -- Date key for joining to dim_date
        to_char(snapshot_date, 'YYYYMMDD')::integer as date_key,

        -- Attributes
        is_anonymous,
        stoplight_skipped,

        -- Date fields
        snapshot_date,
        snapshot_created_at,

        -- Audit fields
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
