-- Custom test: Validate that dimension_name is populated when dimension_id exists
-- This test allows both standard dimensions (6 canonical) and custom dimensions
-- It only fails when dimension_id exists but dimension_name is NULL or invalid

with dim_indicator_questions as (
    select
        indicator_key,
        survey_indicator_id,
        dimension_id,
        dimension_name
    from {{ ref('dim_indicator_questions') }}
),

invalid_dimensions as (
    -- Case 1: dimension_id exists but dimension_name is NULL
    select
        'dim_indicator_questions' as table_name,
        'Missing dimension_name with valid dimension_id' as failure_reason,
        survey_indicator_id,
        dimension_id,
        dimension_name
    from dim_indicator_questions
    where dimension_id is not null
      and dimension_name is null

    union all

    -- Case 2: dimension_id exists but dimension_name is empty string
    select
        'dim_indicator_questions' as table_name,
        'Empty dimension_name with valid dimension_id' as failure_reason,
        survey_indicator_id,
        dimension_id,
        dimension_name
    from dim_indicator_questions
    where dimension_id is not null
      and trim(dimension_name) = ''
)

-- Return rows that fail validation (should be 0 rows for test to pass)
select * from invalid_dimensions
