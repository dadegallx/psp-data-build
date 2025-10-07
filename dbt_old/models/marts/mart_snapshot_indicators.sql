with enriched_indicators as (
    select * from {{ ref('int_snapshot_indicators_enriched') }}
),

definitions as (
    select * from {{ ref('int_indicator_definitions_deduped') }}
    where definition_rank = 1  -- Take first definition for duplicates
),

indicator_master as (
    select * from {{ ref('stg_indicators') }}
),

families as (
    select * from {{ ref('stg_family') }}
)

select
    -- Response identifiers
    ei.indicator_response_id,
    ei.snapshot_id,
    ei.family_id,
    ei.survey_definition_id,

    -- Indicator details
    ei.code_name,
    ei.value,
    case
        when ei.value = 1 then 'Red'
        when ei.value = 2 then 'Yellow'
        when ei.value = 3 then 'Green'
        else 'Unknown'
    end as value_label,

    -- Definition details (survey-specific)
    d.short_name as indicator_name,
    d.definition as indicator_definition,
    d.dimension,

    -- Master indicator link
    im.met_short_name as master_indicator_name,
    im.met_description as master_indicator_description,

    -- Snapshot context
    ei.snapshot_date,
    ei.snapshot_number,
    case
        when ei.snapshot_number = 1 then 'Baseline'
        else 'Follow-up ' || (ei.snapshot_number - 1)::text
    end as survey_round,
    ei.is_last as is_current_status,

    -- Family context
    f.name as family_name,
    f.code as family_code,
    f.organization_id,
    f.application_id,
    f.latitude as family_latitude,
    f.longitude as family_longitude,

    -- Data quality context
    ei.mapping_quality,
    ei.definition_count,
    ei.anonymous,
    ei.additional

from enriched_indicators ei
left join definitions d
    on ei.code_name = d.code_name
    and ei.survey_definition_id = d.survey_definition_id
left join indicator_master im
    on d.indicator_master_id = im.indicator_master_id
left join families f
    on ei.family_id = f.family_id