with snapshot_economic as (
    select * from {{ ref('stg_snapshot_economic') }}
),

snapshots as (
    select * from {{ ref('stg_snapshots') }}
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

-- Join all dimensions
economic_responses as (
    select
        -- Snapshot context
        se.snapshot_id,
        s.snapshot_number,
        s.is_last,
        s.snapshot_date,

        -- Foreign keys
        f.family_key,
        eq.economic_question_key,
        o.organization_key,
        sd.survey_definition_key,

        -- Question identifier and type
        se.code_name,
        se.answer_type,

        -- Answer values (polymorphic)
        se.answer_value,
        se.answer_number,
        se.answer_date,
        se.answer_options

    from snapshot_economic as se
    inner join snapshots as s
        on se.snapshot_id = s.snapshot_id
    inner join families as f
        on se.family_id = f.family_id
    inner join economic_questions as eq
        on se.survey_definition_id = eq.survey_definition_id
        and se.code_name = eq.code_name
    inner join organizations as o
        on s.organization_id = o.organization_id
    inner join survey_definitions as sd
        on s.survey_definition_id = sd.survey_definition_id

    where s.snapshot_date is not null
),

-- Pivot the 5 priority economic fields with type-specific columns
final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key([
            'er.snapshot_id',
            'er.economic_question_key'
        ]) }} as family_economic_snapshot_key,

        -- Foreign keys to dimensions
        to_char(er.snapshot_date, 'YYYYMMDD')::integer as date_key,
        er.family_key,
        er.economic_question_key,
        er.organization_key,
        er.survey_definition_key,

        -- Degenerate dimensions
        er.snapshot_id,
        er.snapshot_number,
        er.is_last,

        -- Measures: householdMonthlyIncome (numeric + currency)
        case
            when er.code_name = 'householdMonthlyIncome'
            then er.answer_number
        end as household_monthly_income,
        case
            when er.code_name like '%currency%' or er.code_name like '%Currency%'
            then er.answer_value
        end as income_currency_code,

        -- Measures: housingSituation (single-select vs multi-select)
        case
            when er.code_name = 'housingSituation' and er.answer_type in ('select', 'radio')
            then er.answer_value
        end as housing_situation_single,
        case
            when er.code_name = 'housingSituation' and er.answer_type = 'checkbox'
            then er.answer_options
        end as housing_situation_multi,

        -- Measures: activityMain (single-select, multi-select, and text)
        case
            when er.code_name = 'activityMain' and er.answer_type in ('select', 'radio')
            then er.answer_value
        end as activity_main_single,
        case
            when er.code_name = 'activityMain' and er.answer_type = 'checkbox'
            then er.answer_options
        end as activity_main_multi,
        case
            when er.code_name = 'activityMain' and er.answer_type = 'text'
            then er.answer_value
        end as activity_main_text,

        -- Measures: familyCar (boolean/radio)
        case
            when er.code_name = 'familyCar' and er.answer_type in ('radio', 'checkbox', 'select')
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
            when er.code_name = 'areaOfResidence' and er.answer_type = 'select'
            then er.answer_value
        end as area_of_residence_select,
        case
            when er.code_name = 'areaOfResidence' and er.answer_type = 'radio'
            then er.answer_value
        end as area_of_residence_radio

    from economic_responses as er

    where er.code_name in (
        'householdMonthlyIncome',
        'housingSituation',
        'activityMain',
        'familyCar',
        'areaOfResidence'
    )
    -- Also capture currency code responses which often have different code_names
    or er.code_name like '%currency%'
    or er.code_name like '%Currency%'
)

select * from final
