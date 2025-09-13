{{ config(materialized='view') }}

-- Survey engagement and retention metrics
-- Grain: One row per organization

with family_survey_counts as (
    select
        s.organization_id,
        s.family_id,
        count(*) as survey_count,
        min(s.created_at / 1000) as first_survey_timestamp,
        max(s.created_at / 1000) as last_survey_timestamp,
        sum(case when s.snapshot_number = 1 then 1 else 0 end) as baseline_count,
        sum(case when s.snapshot_number > 1 then 1 else 0 end) as followup_count
    from {{ source('data_collect', 'snapshot') }} s
    inner join {{ source('data_collect', 'survey_definition') }} sd
        on s.survey_definition_id = sd.id
    group by s.organization_id, s.family_id
),

organization_metrics as (
    select
        organization_id,
        count(distinct family_id) as total_families_enrolled,
        sum(case when baseline_count > 0 then 1 else 0 end) as families_with_baseline,
        sum(case when followup_count > 0 then 1 else 0 end) as families_with_followup,
        sum(case when survey_count = 1 then 1 else 0 end) as families_with_1_survey,
        sum(case when survey_count = 2 then 1 else 0 end) as families_with_2_surveys,
        sum(case when survey_count >= 3 then 1 else 0 end) as families_with_3plus_surveys,
        avg(survey_count) as avg_surveys_per_family,
        max(last_survey_timestamp) as last_survey_timestamp,
        avg(
            case
                when followup_count > 0 and baseline_count > 0
                then (last_survey_timestamp - first_survey_timestamp) / 86400  -- Convert seconds to days
                else null
            end
        ) as avg_days_between_surveys
    from family_survey_counts
    group by organization_id
),

organization_details as (
    select
        o.id as organization_id,
        o.name as organization_name,
        a.name as hub_name,
        a.country
    from {{ source('ps_network', 'organizations') }} o
    left join {{ source('ps_network', 'applications') }} a
        on o.application_id = a.id
)

select
    om.organization_id,
    od.organization_name,
    od.hub_name,
    od.country,
    om.total_families_enrolled,
    om.families_with_baseline,
    om.families_with_followup,
    case
        when om.total_families_enrolled > 0
        then round(om.families_with_baseline::numeric / om.total_families_enrolled::numeric, 4)
        else null
    end as baseline_completion_rate,
    case
        when om.families_with_baseline > 0
        then round(om.families_with_followup::numeric / om.families_with_baseline::numeric, 4)
        else null
    end as followup_rate,
    round(om.avg_days_between_surveys, 1) as avg_days_between_surveys,
    round(om.avg_surveys_per_family, 1) as avg_surveys_per_family,
    om.families_with_1_survey,
    om.families_with_2_surveys,
    om.families_with_3plus_surveys,
    case
        when om.last_survey_timestamp is not null
        then to_timestamp(om.last_survey_timestamp)::date
        else null
    end as last_survey_date,
    case
        when om.last_survey_timestamp is not null
        then current_date - to_timestamp(om.last_survey_timestamp)::date
        else null
    end as days_since_last_survey
from organization_metrics om
left join organization_details od
    on om.organization_id = od.organization_id
where om.total_families_enrolled >= 3  -- Minimum threshold for meaningful metrics