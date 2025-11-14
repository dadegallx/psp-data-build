{{
  config(
    materialized='view',
    tags=['staging', 'economic']
  )
}}

with snapshot_economic_source as (
    select * from {{ source('data_collect', 'snapshot_economic') }}
),

snapshots as (
    select * from {{ ref('stg_snapshots') }}
),

survey_economic as (
    select * from {{ ref('stg_survey_economic') }}
),

-- Enrich snapshot_economic with survey_definition_id via snapshot join
economic_responses as (
    select
        se.id,
        se.snapshot_id,
        se.code_name,
        se.answer_type,
        se.answer_value,
        se.answer_number,
        se.answer_date,
        se.answer_options,
        se.created_date,
        se.last_modified_date,

        -- Enriched fields from snapshot
        s.survey_definition_id,
        s.family_id,
        s.snapshot_date

    from snapshot_economic_source as se
    inner join snapshots as s
        on se.snapshot_id = s.snapshot_id
),

-- Join to survey_economic to filter out orphaned code_names
-- This inner join removes 244 orphaned code_names without matching survey definitions
final as (
    select
        -- Primary key
        er.id as snapshot_economic_id,

        -- Foreign keys
        er.snapshot_id,
        er.survey_definition_id,
        er.family_id,

        -- Question identifier
        er.code_name,

        -- Answer type and values
        er.answer_type,
        er.answer_value,
        er.answer_number,
        case
            when er.answer_date is not null
            then to_timestamp(er.answer_date / 1000)
        end as answer_date,
        er.answer_options,

        -- Snapshot context
        er.snapshot_date,

        -- Audit fields
        er.created_date,
        er.last_modified_date

    from economic_responses as er
    inner join survey_economic as sve
        on er.survey_definition_id = sve.survey_definition_id
        and er.code_name = sve.code_name
)

select * from final
