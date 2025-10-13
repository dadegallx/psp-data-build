{{ config(
    materialized="incremental",
    unique_key="indicator_key",
    tags=["intermediate", "indicator", "experimental"]
) }}

/*
    Lightweight indicator explosion for current state analysis.

    Grain: 1 row per indicator per snapshot (for latest snapshots with stoplight)

    Note: This is an experimental/quick-win model for dimension-level analysis.
    Official indicator KPIs (ΔScore, time-to-green, priority gap) will be in Phase 2.
*/

with current_snap as (
    -- Get latest snapshot with stoplight data for each family
    select
        s.snapshot_id,
        s.family_id,
        s.organization_id,
        s.application_id,
        s.survey_definition_id,
        s.snapshot_ts,
        s.anonymous
    from {{ ref('fact_snapshot') }} s
    where s.is_last_with_stoplight = true
),

stoplight_raw as (
    select
        sl.snapshot_id,
        sl.code_name,
        sl.value,
        sl.id,
        -- Deduplicate: take the latest record for each snapshot_id + code_name
        row_number() over (
            partition by sl.snapshot_id, sl.code_name
            order by sl.id desc
        ) as rn
    {% if target.name in ['heroes-dev', 'heroes-prod'] %}
        from {{ source('heroes_collect', 'heroes_snapshot_stoplight') }} sl
    {% else %}
        from {{ source('data_collect', 'snapshot_stoplight') }} sl
    {% endif %}
    where sl.value in (1, 2, 3)  -- Only valid stoplight values (Red, Yellow, Green)
        -- Exclude: 0=skipped/not applicable, 9=not answered/other
),

stoplight as (
    select
        snapshot_id,
        code_name,
        value
    from stoplight_raw
    where rn = 1  -- Take only the most recent record for each indicator
),

survey_map as (
    select
        ss.survey_definition_id,
        ss.code_name,
        ss.survey_dimension_id as dimension_id,
        ss.dimension as dimension_name
    {% if target.name in ['heroes-dev', 'heroes-prod'] %}
        from {{ source('heroes_collect', 'heroes_survey_stoplight') }} ss
    {% else %}
        from {{ source('data_collect', 'survey_stoplight') }} ss
    {% endif %}
    where ss.survey_dimension_id is not null
)

select
    -- Composite key (must include dimension_id since same indicator can be in multiple dimensions)
    c.snapshot_id || '__' || st.code_name || '__' || m.dimension_id as indicator_key,

    -- Snapshot context
    c.snapshot_id,
    c.family_id,
    c.organization_id,
    c.application_id,
    c.survey_definition_id,
    c.snapshot_ts,
    c.anonymous,

    -- Dimension context
    m.dimension_id,
    m.dimension_name,

    -- Indicator data
    st.code_name as indicator_code_name,
    st.value as indicator_value,
    {{ indicator_color_to_score('st.value') }} as indicator_score

from current_snap c
inner join stoplight st
    on st.snapshot_id = c.snapshot_id
inner join survey_map m
    on m.survey_definition_id = c.survey_definition_id
    and m.code_name = st.code_name

{% if is_incremental() %}
    -- Incremental: only process snapshots updated in last 30 days
    where c.snapshot_ts >= (current_timestamp - interval '30 day')
{% endif %}
