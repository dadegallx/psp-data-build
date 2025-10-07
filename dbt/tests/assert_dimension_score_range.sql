/*
    Data quality test: Verify that dimension_score is within valid range [0, 1]

    Since Red=0, Yellow=0.5, Green=1, the average score must be between 0 and 1
*/

with invalid_scores as (
    select
        family_id,
        dimension_id,
        dimension_name,
        dimension_score,
        indicators_count
    from {{ ref('mart_family_dimension_current') }}
    where
        dimension_score < 0
        or dimension_score > 1
        or dimension_score is null
)

-- Test passes when no rows are returned (all scores are in valid range)
select * from invalid_scores
