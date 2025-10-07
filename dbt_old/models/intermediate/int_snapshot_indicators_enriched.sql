with snapshot_indicators as (
    select * from {{ ref('stg_snapshot_stoplight') }}
),

snapshots as (
    select * from {{ ref('stg_snapshot') }}
),

indicator_definitions as (
    select * from {{ ref('stg_survey_stoplight') }}
),

-- Identify duplicate definitions for quality flagging
quality_check as (
    select
        survey_definition_id,
        code_name,
        count(*) as definition_count
    from indicator_definitions
    group by survey_definition_id, code_name
    having count(*) > 1
)

select
    si.indicator_response_id,
    si.snapshot_id,
    si.code_name,
    si.value,
    si.additional,

    -- Snapshot context
    s.family_id,
    s.survey_definition_id,
    s.snapshot_date,
    s.snapshot_number,
    s.is_last,
    s.anonymous,
    s.stoplight_skipped,

    -- Data quality flags
    case
        when qc.survey_definition_id is not null then 'ambiguous'
        else 'unique'
    end as mapping_quality,

    coalesce(qc.definition_count, 1) as definition_count

from snapshot_indicators si
join snapshots s on si.snapshot_id = s.snapshot_id
left join quality_check qc
    on s.survey_definition_id = qc.survey_definition_id
    and si.code_name = qc.code_name