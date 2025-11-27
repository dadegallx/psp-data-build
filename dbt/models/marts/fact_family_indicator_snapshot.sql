with snapshots as (
    select * from {{ ref('stg_snapshots') }}
),

snapshot_stoplight as (
    select * from {{ ref('stg_snapshot_stoplight') }}
),

-- Survey indicators for resolving code_name → survey_indicator_id
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

-- Join with indicator dimension to get indicator_key
stoplight_with_indicators as (
    select
        swsi.snapshot_id,
        swsi.indicator_status_value,
        ind.indicator_key
    from stoplight_with_survey_indicator swsi
    inner join indicators ind
        on swsi.survey_indicator_id = ind.survey_indicator_id
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
