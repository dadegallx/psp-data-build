{{
  config(
    materialized='view',
    tags=['staging']
  )
}}

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
    -- Pre-deduplicate survey_stoplight by picking first order_number per code_name
    -- Handles rare cases (<0.01%) where same code_name appears multiple times in one survey
    select distinct on (survey_definition_id, code_name)
        id as indicator_id,
        survey_definition_id,
        code_name
    from {{ source('data_collect', 'survey_stoplight') }}
    order by survey_definition_id, code_name, order_number
),

enriched as (
    select
        -- Primary key
        source.id as snapshot_stoplight_id,

        -- Foreign keys
        source.snapshot_id,
        si.indicator_id,  -- Derived via FK chain: snapshot_stoplight → snapshot → survey_stoplight

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
