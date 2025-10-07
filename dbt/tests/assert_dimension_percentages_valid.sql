/*
    Data quality test: Verify that color percentages sum to approximately 1.0
    (allowing small floating point tolerance)

    This ensures that pct_red + pct_yellow + pct_green = 100% for each family-dimension
*/

with dimension_checks as (
    select
        family_id,
        dimension_id,
        dimension_name,
        pct_red,
        pct_yellow,
        pct_green,
        (pct_red + pct_yellow + pct_green) as total_pct
    from {{ ref('mart_family_dimension_current') }}
    where
        -- Total should be approximately 1.0 (with small floating point tolerance)
        abs((pct_red + pct_yellow + pct_green) - 1.0) > 0.001
)

-- Test passes when no rows are returned (all percentages sum to ~1.0)
select * from dimension_checks
