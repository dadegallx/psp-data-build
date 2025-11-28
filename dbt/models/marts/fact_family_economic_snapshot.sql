with snapshot_economic as (
    select * from {{ ref('stg_snapshot_economic') }}
),

snapshots as (
    select * from {{ ref('stg_snapshots') }}
),

survey_economic as (
    select * from {{ ref('stg_survey_economic') }}
),

families as (
    select * from {{ ref('dim_family') }}
),

economic_questions as (
    select * from {{ ref('dim_economic_questions') }}
),

organizations as (
    select * from {{ ref('dim_organization') }}
),

survey_definitions as (
    select * from {{ ref('dim_survey_definition') }}
),

-- Enrich snapshot_economic with survey_definition_id and convert answer types
economic_responses_enriched as (
    select
        se.snapshot_economic_id,
        se.snapshot_id,
        se.code_name,
        se.answer_type,
        se.answer_value,

        -- Convert polymorphic answer values
        case
            when se.answer_type in ('number', 'string')
            and se.answer_value ~ '^[0-9]+\.?[0-9]*$'
            then se.answer_value::numeric
        end as answer_number,
        case
            when se.answer_type = 'date' and se.answer_value is not null
            then to_timestamp(se.answer_value::bigint / 1000)
        end as answer_date,
        case
            when se.answer_type = 'checkbox' and se.answer_multiple_value is not null
            then array_to_string(se.answer_multiple_value, ', ')
        end as answer_options,

        -- Enriched fields from snapshot
        s.survey_definition_id,
        s.family_id,
        s.organization_id,
        s.snapshot_date,
        s.snapshot_number,
        s.is_last

    from snapshot_economic se
    inner join snapshots s
        on se.snapshot_id = s.snapshot_id
),

-- Filter to valid code_names that exist in survey_economic
-- This removes orphaned code_names without matching survey definitions
economic_responses_filtered as (
    select er.*
    from economic_responses_enriched er
    inner join survey_economic sve
        on er.survey_definition_id = sve.survey_definition_id
        and er.code_name = sve.code_name
),

-- Join all dimensions
economic_responses as (
    select
        -- Snapshot context
        er.snapshot_id,
        er.snapshot_number,
        er.is_last,
        er.snapshot_date,

        -- Foreign keys (natural keys)
        er.family_id,
        er.organization_id,
        er.survey_definition_id,

        -- Question identifier and type
        er.code_name,
        er.answer_type,

        -- Answer values (polymorphic)
        er.answer_value,
        er.answer_number,
        er.answer_date,
        er.answer_options

    from economic_responses_filtered er
    inner join families f
        on er.family_id = f.family_id
    inner join economic_questions eq
        on er.survey_definition_id = eq.survey_definition_id
        and er.code_name = eq.code_name
    inner join organizations o
        on er.organization_id = o.organization_id
    inner join survey_definitions sd
        on er.survey_definition_id = sd.survey_definition_id

    where er.snapshot_date is not null
),

-- Pivot the 5 priority economic fields with type-specific columns
final as (
    select
        -- Foreign keys to dimensions (natural keys)
        to_char(er.snapshot_date, 'YYYYMMDD')::integer as date_key,
        er.family_id,
        er.organization_id,
        er.survey_definition_id,
        er.code_name,  -- Part of composite key for dim_economic_questions

        -- Degenerate dimensions
        er.snapshot_id,
        er.snapshot_number,
        er.is_last,

        -- Measures: householdMonthlyIncome (numeric + currency)
        case
            when er.code_name = 'householdmonthlyincome'
            then er.answer_number
        end as household_monthly_income,
        case
            when er.code_name like '%currency%'
            then er.answer_value
        end as income_currency_code,

        -- Measures: housingSituation (single-select vs multi-select)
        case
            when er.code_name = 'housingsituation' and er.answer_type in ('select', 'radio')
            then er.answer_value
        end as housing_situation_single,
        case
            when er.code_name = 'housingsituation' and er.answer_type = 'checkbox'
            then er.answer_options
        end as housing_situation_multi,

        -- Measures: activityMain (single-select, multi-select, and text)
        case
            when er.code_name = 'activitymain' and er.answer_type in ('select', 'radio')
            then er.answer_value
        end as activity_main_single,
        case
            when er.code_name = 'activitymain' and er.answer_type = 'checkbox'
            then er.answer_options
        end as activity_main_multi,
        case
            when er.code_name = 'activitymain' and er.answer_type = 'text'
            then er.answer_value
        end as activity_main_text,

        -- Measures: familyCar (boolean/radio)
        case
            when er.code_name = 'familycar' and er.answer_type in ('radio', 'checkbox', 'select')
            then case
                when lower(er.answer_value) in ('yes', 'true', '1', 'sí', 'sim')
                then true
                when lower(er.answer_value) in ('no', 'false', '0', 'não')
                then false
                else null
            end
        end as family_car,

        -- Measures: areaOfResidence (select vs radio)
        case
            when er.code_name = 'areaofresidence' and er.answer_type = 'select'
            then er.answer_value
        end as area_of_residence_select,
        case
            when er.code_name = 'areaofresidence' and er.answer_type = 'radio'
            then er.answer_value
        end as area_of_residence_radio

    from economic_responses er

    where er.code_name in (
        'householdmonthlyincome',
        'housingsituation',
        'activitymain',
        'familycar',
        'areaofresidence'
    )
    -- Also capture currency code responses
    or er.code_name like '%currency%'
)

select * from final
