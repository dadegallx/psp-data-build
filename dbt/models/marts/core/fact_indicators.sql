{{
    config(
        materialized='table',
        tags=['mart', 'semantic_layer']
    )
}}

{#
    ENRICHED INDICATOR FACT TABLE

    Grain: One row per family × indicator × snapshot

    Score columns:
    - current_score: The indicator value for this row (0=skipped, 1=red, 2=yellow, 3=green)
    - baseline_score: Value from baseline snapshot (NULL if indicator didn't exist in baseline)
    - previous_score: Value from the previous snapshot (NULL for first observation)

    Priority/Achievement columns:
    - is_priority: TRUE if family marked this indicator as a priority
    - has_achievement: TRUE if family marked this indicator as achieved
    - was_priority_in_previous: TRUE if this indicator was a priority in the previous snapshot

    Use Cases:
    - Sankey diagrams: Filter WHERE is_last = TRUE, map baseline_score → current_score
    - Progress analysis: Compare current_score - baseline_score (only valid when baseline_score IS NOT NULL)
    - Momentum: Compare current_score - previous_score
    - Achievement rate: Filter WHERE has_achievement AND was_priority_in_previous

    Notes:
    - baseline_score = NULL means the indicator was added after the baseline survey
    - Join to stg_snapshot_stoplight_priority/achievement via snapshot_stoplight_id for details
#}

-- Source CTEs (self-contained, mirrors fact_family_indicator_snapshot logic)
with snapshots as (
    select * from {{ ref('fact_snapshots') }}
),

snapshot_stoplight as (
    select * from {{ ref('stg_snapshot_stoplight') }}
),

survey_indicators as (
    select
        survey_indicator_id,
        survey_definition_id,
        indicator_code_name
    from {{ ref('stg_survey_stoplight') }}
),

families as (
    select * from {{ ref('dim_family') }}
),

organizations as (
    select * from {{ ref('dim_organization') }}
),

survey_definitions as (
    select * from {{ ref('dim_survey_definition') }}
),

priorities as (
    select * from {{ ref('stg_snapshot_stoplight_priority') }}
),

achievements as (
    select * from {{ ref('stg_snapshot_stoplight_achievement') }}
),

-- Resolve code_name to survey_indicator_id via snapshot → survey_definition
-- Note: INNER JOIN filters out orphaned responses (code_names removed from survey definitions)
-- See DATA_QUALITY_ISSUES.md "Orphaned Indicator Responses" for details
stoplight_with_survey_indicator as (
    select
        ss.snapshot_stoplight_id,
        ss.snapshot_id,
        ss.indicator_code_name,
        ss.indicator_status_value,
        si.survey_indicator_id
    from snapshot_stoplight ss
    inner join snapshots s
        on ss.snapshot_id = s.snapshot_id
    inner join survey_indicators si
        on s.survey_definition_id = si.survey_definition_id
        and ss.indicator_code_name = si.indicator_code_name
),

-- Join all sources
joined as (
    select
        snapshots.snapshot_id,
        snapshots.snapshot_number,
        snapshots.is_last,
        snapshots.is_baseline,
        snapshots.max_snapshot_number,
        snapshots.snapshot_date,
        snapshots.family_id,
        snapshots.organization_id,
        stoplight_with_survey_indicator.survey_indicator_id,
        snapshots.survey_definition_id,
        snapshots.project_id,

        -- Primary key; also FK for joining to priority/achievement details
        stoplight_with_survey_indicator.snapshot_stoplight_id,

        -- Normalize score: 0=skipped, 1=red, 2=yellow, 3=green, invalid→NULL
        case
            when stoplight_with_survey_indicator.indicator_status_value in (0, 1, 2, 3)
            then stoplight_with_survey_indicator.indicator_status_value
            else null
        end as current_score,

        -- Priority/achievement flags (sparse - most will be false)
        priorities.snapshot_stoplight_id is not null as is_priority,
        achievements.snapshot_stoplight_id is not null as has_achievement

    from snapshots
    inner join families
        on snapshots.family_id = families.family_id
    inner join organizations
        on snapshots.organization_id = organizations.organization_id
    inner join survey_definitions
        on snapshots.survey_definition_id = survey_definitions.survey_definition_id
    inner join stoplight_with_survey_indicator
        on snapshots.snapshot_id = stoplight_with_survey_indicator.snapshot_id
    left join priorities
        on stoplight_with_survey_indicator.snapshot_stoplight_id = priorities.snapshot_stoplight_id
    left join achievements
        on stoplight_with_survey_indicator.snapshot_stoplight_id = achievements.snapshot_stoplight_id
),

-- Add window function columns
enriched as (
    select
        -- 1. IDENTIFIERS
        snapshot_stoplight_id,
        snapshot_id,
        family_id,
        organization_id,
        survey_indicator_id,
        survey_definition_id,
        project_id,

        -- 2. TEMPORAL / CHRONOLOGY
        to_char(snapshot_date, 'YYYYMMDD')::integer as date_key,
        snapshot_number,
        is_last,
        is_baseline,
        max_snapshot_number,

        -- 3. SCORES
        current_score,

        max(case when is_baseline then current_score end) over (
            partition by family_id, survey_indicator_id
        ) as baseline_score,

        lag(current_score) over (
            partition by family_id, survey_indicator_id
            order by snapshot_number
        ) as previous_score,

        -- 4. FLAGS / ATTRIBUTES
        is_priority,
        has_achievement,
        
        lag(is_priority) over (
            partition by family_id, survey_indicator_id
            order by snapshot_number
        ) as was_priority_in_previous

    from joined
)

select * from enriched
