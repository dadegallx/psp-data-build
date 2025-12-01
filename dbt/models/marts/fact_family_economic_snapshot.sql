with snapshots as (
    select * from {{ ref('stg_snapshots') }}
),

snapshot_economic as (
    select * from {{ ref('stg_snapshot_economic') }}
),

-- Survey economic questions for resolving code_name → survey_economic_id
survey_economic as (
    select
        survey_economic_id,
        survey_definition_id,
        code_name
    from {{ ref('stg_survey_economic') }}
),

families as (
    select * from {{ ref('dim_family') }}
),

organizations as (
    select * from {{ ref('dim_organization') }}
),

economic_questions as (
    select * from {{ ref('dim_economic_questions') }}
),

survey_definitions as (
    select * from {{ ref('dim_survey_definition') }}
),

-- Resolve code_name to survey_economic_id via snapshot → survey_definition
economic_with_survey_economic as (
    select
        se.snapshot_economic_id,
        se.snapshot_id,
        se.code_name,
        se.answer_type,
        se.answer_value,
        se.answer_multiple_value,
        sve.survey_economic_id
    from snapshot_economic se
    inner join snapshots s
        on se.snapshot_id = s.snapshot_id
    inner join survey_economic sve
        on s.survey_definition_id = sve.survey_definition_id
        and se.code_name = sve.code_name
),

-- Join with economic questions dimension to validate survey_economic_id exists
economic_with_questions as (
    select
        ewse.snapshot_id,
        ewse.code_name,
        ewse.answer_type,
        ewse.answer_value,
        ewse.answer_multiple_value,
        ewse.survey_economic_id
    from economic_with_survey_economic ewse
    inner join economic_questions eq
        on ewse.survey_economic_id = eq.survey_economic_id
),

-- Convert polymorphic answer values to typed columns
economic_typed as (
    select
        snapshot_id,
        code_name,
        answer_type,
        survey_economic_id,

        -- value_text: text/select/radio responses, or pipe-separated for checkbox
        case
            when answer_type in ('text', 'select', 'radio', 'string')
            then answer_value
            when answer_type = 'checkbox' and answer_multiple_value is not null
            then array_to_string(answer_multiple_value, '|')
            else null
        end as value_text,

        -- value_number: numeric responses
        case
            when answer_type in ('number', 'string')
            and answer_value ~ '^-?[0-9]+\.?[0-9]*$'
            then answer_value::numeric
            else null
        end as value_number,

        -- value_date: date responses (source stores as bigint milliseconds)
        case
            when answer_type = 'date' and answer_value is not null
            and answer_value ~ '^[0-9]+$'
            then to_timestamp(answer_value::bigint / 1000)
            else null
        end as value_date

    from economic_with_questions
),

joined as (
    select
        snapshots.snapshot_id,
        snapshots.snapshot_number,
        snapshots.is_last,
        snapshots.snapshot_date,

        -- Foreign keys to dimensions (natural keys)
        snapshots.family_id,
        snapshots.organization_id,
        economic_typed.survey_economic_id,
        snapshots.survey_definition_id,

        -- Answer metadata (degenerate dimension)
        economic_typed.answer_type,

        -- Typed value measures
        economic_typed.value_text,
        economic_typed.value_number,
        economic_typed.value_date

    from snapshots
    inner join families
        on snapshots.family_id = families.family_id
    inner join organizations
        on snapshots.organization_id = organizations.organization_id
    inner join survey_definitions
        on snapshots.survey_definition_id = survey_definitions.survey_definition_id
    inner join economic_typed
        on snapshots.snapshot_id = economic_typed.snapshot_id
),

final as (
    select
        -- Foreign keys to dimensions (natural keys)
        to_char(snapshot_date, 'YYYYMMDD')::integer as date_key,
        family_id,
        organization_id,
        survey_economic_id,
        survey_definition_id,

        -- Degenerate dimensions
        snapshot_id,
        snapshot_number,
        is_last,
        answer_type,

        -- Typed value measures
        value_text,
        value_number,
        value_date

    from joined
)

select * from final
