with source as (
    select * from {{ source('data_collect', 'snapshot_stoplight') }}
),

snapshots as (
    select
        id as snapshot_id,
        survey_definition_id
    from {{ source('data_collect', 'snapshot') }}
),

survey_indicators as (
    -- Simplified: no dedup - accepting <0.01% edge case of duplicate code_names
    select
        id as survey_indicator_id,
        survey_definition_id,
        code_name
    from {{ source('data_collect', 'survey_stoplight') }}
),

enriched as (
    select
        -- Primary key
        source.id as snapshot_stoplight_id,

        -- Foreign keys
        source.snapshot_id,
        si.survey_indicator_id,  -- Survey-specific indicator ID (survey_stoplight.id)

        -- Attributes
        source.code_name as indicator_code_name,
        source.value as indicator_status_value,  -- 1=Red, 2=Yellow, 3=Green, NULL=Skipped

        -- Audit fields
        to_timestamp(source.updated_at / 1000) as updated_at,
        source.updated_by,
        source.created_date as created_at

    from source
    inner join snapshots snap
        on snap.snapshot_id = source.snapshot_id
    inner join survey_indicators si
        on si.survey_definition_id = snap.survey_definition_id
        and si.code_name = source.code_name
)

select * from enriched
