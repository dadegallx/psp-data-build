{{
    config(
        materialized='table',
        tags=['mart', 'semantic_layer']
    )
}}

{#
    ENRICHED INDICATOR FACT TABLE

    Grain: One row per family × indicator × snapshot

    Adds window function columns for progress analysis:
    - baseline_score: First recorded value for this family+indicator
    - previous_score: Value from the previous snapshot (NULL for first)
    - current_score: The value for this specific row

    Use Cases:
    - Sankey diagrams: Filter WHERE is_last = TRUE, map baseline_score → current_score
    - Progress analysis: Compare current_score - baseline_score
    - Momentum: Compare current_score - previous_score
#}

-- Source CTEs (self-contained, mirrors fact_family_indicator_snapshot logic)
with snapshots as (
    select * from {{ ref('int_snapshots') }}
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

indicators as (
    select * from {{ ref('dim_indicator_questions') }}
),

survey_definitions as (
    select * from {{ ref('dim_survey_definition') }}
),

-- Resolve code_name to survey_indicator_id via snapshot → survey_definition
stoplight_with_survey_indicator as (
    select
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

-- Validate survey_indicator_id exists in dimension
stoplight_validated as (
    select
        swsi.snapshot_id,
        swsi.indicator_status_value,
        swsi.survey_indicator_id
    from stoplight_with_survey_indicator swsi
    inner join indicators ind
        on swsi.survey_indicator_id = ind.survey_indicator_id
),

-- Join all sources
joined as (
    select
        snapshots.snapshot_id,
        snapshots.snapshot_number,
        snapshots.is_last,
        snapshots.max_snapshot_number,
        snapshots.snapshot_date,
        snapshots.family_id,
        snapshots.organization_id,
        stoplight_validated.survey_indicator_id,
        snapshots.survey_definition_id,
        snapshots.project_id,
        -- Normalize score: 0=skipped, 1=red, 2=yellow, 3=green, invalid→NULL
        case
            when stoplight_validated.indicator_status_value in (0, 1, 2, 3)
            then stoplight_validated.indicator_status_value
            else null
        end as current_score
    from snapshots
    inner join families
        on snapshots.family_id = families.family_id
    inner join organizations
        on snapshots.organization_id = organizations.organization_id
    inner join survey_definitions
        on snapshots.survey_definition_id = survey_definitions.survey_definition_id
    inner join stoplight_validated
        on snapshots.snapshot_id = stoplight_validated.snapshot_id
),

-- Add window function columns
enriched as (
    select
        -- Foreign keys to dimensions
        to_char(snapshot_date, 'YYYYMMDD')::integer as date_key,
        family_id,
        organization_id,
        survey_indicator_id,
        survey_definition_id,
        project_id,

        -- Degenerate dimensions
        snapshot_id,
        snapshot_number,
        is_last,
        max_snapshot_number,

        -- Current score (this row's value)
        current_score,

        -- Baseline score (first value for this family+indicator)
        first_value(current_score) over (
            partition by family_id, survey_indicator_id
            order by snapshot_date, snapshot_id
            rows between unbounded preceding and unbounded following
        ) as baseline_score,

        -- Previous score (NULL for first snapshot)
        lag(current_score) over (
            partition by family_id, survey_indicator_id
            order by snapshot_date, snapshot_id
        ) as previous_score

    from joined
)

select * from enriched
