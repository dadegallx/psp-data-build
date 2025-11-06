{{
  config(
    materialized='table',
    tags=['mart', 'fact', 'core']
  )
}}

with snapshots as (
    select * from {{ ref('stg_snapshots') }}
),

snapshot_stoplight as (
    select * from {{ ref('stg_snapshot_stoplight') }}
),

families as (
    select * from {{ ref('dim_family') }}
),

organizations as (
    select * from {{ ref('dim_organization') }}
),

indicators as (
    select * from {{ ref('dim_indicator') }}
),

survey_definitions as (
    select * from {{ ref('dim_survey_definition') }}
),

-- Join snapshot stoplight values with indicators by indicator_id (clean 1:1 join)
stoplight_with_indicators as (
    select
        snapshot_stoplight.snapshot_id,
        snapshot_stoplight.indicator_status_value,
        indicators.indicator_key,
        indicators.indicator_id
    from snapshot_stoplight
    inner join indicators
        on snapshot_stoplight.indicator_id = indicators.indicator_id
),

joined as (
    select
        snapshots.snapshot_id,
        snapshots.snapshot_number,
        snapshots.is_last,
        snapshots.snapshot_date,

        -- Foreign keys to dimensions
        families.family_key,
        organizations.organization_key,
        stoplight_with_indicators.indicator_key,
        survey_definitions.survey_definition_key,

        -- Measure
        stoplight_with_indicators.indicator_status_value

    from snapshots
    inner join families
        on snapshots.family_id = families.family_id
    inner join organizations
        on snapshots.organization_id = organizations.organization_id
    inner join survey_definitions
        on snapshots.survey_definition_id = survey_definitions.survey_definition_id
    inner join stoplight_with_indicators
        on snapshots.snapshot_id = stoplight_with_indicators.snapshot_id
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key([
            'snapshot_id',
            'indicator_key'
        ]) }} as family_indicator_snapshot_key,

        -- Foreign keys to dimensions
        to_char(snapshot_date, 'YYYYMMDD')::integer as date_key,
        organization_key,
        indicator_key,
        family_key,
        survey_definition_key,

        -- Degenerate dimensions
        snapshot_id,
        snapshot_number,
        is_last,

        -- Measures
        indicator_status_value

    from joined
)

select * from final
