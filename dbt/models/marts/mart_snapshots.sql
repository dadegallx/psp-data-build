with snapshots as (
    select * from {{ ref('stg_snapshot') }}
),

families as (
    select * from {{ ref('stg_family') }}
),

surveys as (
    select * from {{ ref('stg_survey_definition') }}
),

-- Calculate aggregated indicator metrics per snapshot
indicator_responses as (
    select
        snapshot_id,
        count(*) as total_indicators,
        sum(case when value = 1 then 1 else 0 end) as red_count,
        sum(case when value = 2 then 1 else 0 end) as yellow_count,
        sum(case when value = 3 then 1 else 0 end) as green_count,
        avg(value::decimal) as avg_score,
        -- Calculate poverty score: (green×3 + yellow×2 + red×1) / (total×3)
        (sum(value::decimal) / (count(*) * 3.0)) as poverty_score
    from {{ ref('int_snapshot_indicators_enriched') }}
    where mapping_quality = 'unique'  -- Only use unambiguous mappings
    group by snapshot_id
)

select
    -- Snapshot identifiers
    s.snapshot_id,
    s.family_id,
    s.survey_definition_id,

    -- Snapshot timing
    s.snapshot_date,
    s.snapshot_number,
    case
        when s.snapshot_number = 1 then 'Baseline'
        else 'Follow-up ' || (s.snapshot_number - 1)::text
    end as survey_round,
    s.is_last as is_current_status,

    -- Snapshot metadata
    s.anonymous,
    s.stoplight_skipped,

    -- Family context
    f.name as family_name,
    f.code as family_code,
    f.organization_id,
    f.application_id,
    f.latitude as family_latitude,
    f.longitude as family_longitude,
    f.is_active as family_is_active,

    -- Survey context
    sv.title as survey_title,
    sv.lang as survey_language,
    sv.survey_code,
    sv.active as survey_is_active,

    -- Indicator metrics
    coalesce(ir.total_indicators, 0) as total_indicators,
    coalesce(ir.red_count, 0) as red_count,
    coalesce(ir.yellow_count, 0) as yellow_count,
    coalesce(ir.green_count, 0) as green_count,
    ir.avg_score,
    ir.poverty_score,

    -- Calculated percentages
    case
        when ir.total_indicators > 0
        then round(ir.red_count::decimal / ir.total_indicators * 100, 2)
        else null
    end as red_percentage,

    case
        when ir.total_indicators > 0
        then round(ir.yellow_count::decimal / ir.total_indicators * 100, 2)
        else null
    end as yellow_percentage,

    case
        when ir.total_indicators > 0
        then round(ir.green_count::decimal / ir.total_indicators * 100, 2)
        else null
    end as green_percentage,

    -- Poverty categorization
    case
        when ir.poverty_score >= 0.80 then 'Non-poor'
        when ir.poverty_score >= 0.60 then 'Moderate poverty'
        when ir.poverty_score < 0.60 then 'Severe poverty'
        else 'Unknown'
    end as poverty_category

from snapshots s
left join families f on s.family_id = f.family_id
left join surveys sv on s.survey_definition_id = sv.id
left join indicator_responses ir on s.snapshot_id = ir.snapshot_id