{{ config(materialized='view') }}

-- Current performance metrics for each indicator template
-- Grain: One row per indicator template per organization

with current_snapshots as (
    select
        s.organization_id,
        ssi.id as indicator_template_id,
        ssi.code_name as indicator_code_name,
        ssi.met_short_name as indicator_short_name,
        ss.dimension,
        case
            when sns.value = 1 then 'RED'
            when sns.value = 2 then 'YELLOW'
            when sns.value = 3 then 'GREEN'
            else null
        end as stoplight_color,
        s.family_id
    from {{ source('data_collect', 'survey_definition') }} sd
    inner join {{ source('data_collect', 'survey_stoplight') }} ss
        on sd.id = ss.survey_definition_id
    inner join {{ source('data_collect', 'survey_stoplight_indicator') }} ssi
        on ss.survey_indicator_id = ssi.id
    inner join {{ source('data_collect', 'snapshot') }} s
        on sd.id = s.survey_definition_id
        and s.is_last = true  -- Only current state
    inner join {{ source('data_collect', 'snapshot_stoplight') }} sns
        on s.id = sns.snapshot_id
        and ss.code_name = sns.code_name
    inner join {{ source('ps_families', 'family') }} f
        on s.family_id = f.family_id
        and (f.anonymous = false or f.anonymous is null)  -- Exclude anonymous families
),

performance_metrics as (
    select
        organization_id,
        indicator_template_id,
        indicator_code_name,
        indicator_short_name,
        dimension,
        count(distinct family_id) as families_measured,
        sum(case when stoplight_color = 'RED' then 1 else 0 end) as current_red_count,
        sum(case when stoplight_color = 'YELLOW' then 1 else 0 end) as current_yellow_count,
        sum(case when stoplight_color = 'GREEN' then 1 else 0 end) as current_green_count,
        avg(
            case
                when stoplight_color = 'RED' then 1
                when stoplight_color = 'YELLOW' then 2
                when stoplight_color = 'GREEN' then 3
                else null
            end
        ) as avg_score
    from current_snapshots
    group by
        organization_id,
        indicator_template_id,
        indicator_code_name,
        indicator_short_name,
        dimension
),

organization_details as (
    select
        o.id as organization_id,
        o.name as organization_name,
        a.country
    from {{ source('ps_network', 'organizations') }} o
    left join {{ source('ps_network', 'applications') }} a
        on o.application_id = a.id
)

select
    pm.organization_id,
    pm.indicator_template_id,
    pm.indicator_code_name,
    pm.indicator_short_name,
    pm.dimension,
    od.organization_name,
    od.country,
    pm.families_measured,
    pm.current_red_count,
    pm.current_yellow_count,
    pm.current_green_count,
    case
        when pm.families_measured > 0
        then round(pm.current_red_count::numeric / pm.families_measured::numeric, 4)
        else null
    end as current_red_pct,
    case
        when pm.families_measured > 0
        then round(pm.current_yellow_count::numeric / pm.families_measured::numeric, 4)
        else null
    end as current_yellow_pct,
    case
        when pm.families_measured > 0
        then round(pm.current_green_count::numeric / pm.families_measured::numeric, 4)
        else null
    end as current_green_pct,
    round(pm.avg_score, 2) as avg_score,
    -- Placeholder for improvement_rate - requires historical comparison
    null::numeric as improvement_rate
from performance_metrics pm
left join organization_details od
    on pm.organization_id = od.organization_id
where pm.families_measured >= 5  -- Minimum threshold for reliable metrics