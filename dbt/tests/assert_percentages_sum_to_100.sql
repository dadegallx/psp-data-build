-- Custom test: Validate that percentage columns sum to 100 (within tolerance)
-- This test can be used on any mart with green_pct, yellow_pct, red_pct, skipped_pct columns

-- Test for mart_dimension_metrics
with dimension_metrics_check as (
    select
        dimension_name,
        organization_name,
        country_code,
        snapshot_date,
        green_pct + yellow_pct + red_pct + skipped_pct as total_pct
    from {{ ref('mart_dimension_metrics') }}
    where green_pct is not null
      and yellow_pct is not null
      and red_pct is not null
      and skipped_pct is not null
),

dimension_failures as (
    select
        'mart_dimension_metrics' as table_name,
        dimension_name as identifier,
        total_pct
    from dimension_metrics_check
    where abs(total_pct - 100.0) > 0.5  -- Allow 0.5% tolerance for rounding
),

-- Test for mart_indicator_metrics
indicator_metrics_check as (
    select
        indicator_short_name,
        organization_name,
        country_code,
        snapshot_date,
        green_pct + yellow_pct + red_pct + skipped_pct as total_pct
    from {{ ref('mart_indicator_metrics') }}
    where green_pct is not null
      and yellow_pct is not null
      and red_pct is not null
      and skipped_pct is not null
),

indicator_failures as (
    select
        'mart_indicator_metrics' as table_name,
        indicator_short_name as identifier,
        total_pct
    from indicator_metrics_check
    where abs(total_pct - 100.0) > 0.5  -- Allow 0.5% tolerance for rounding
),

all_failures as (
    select * from dimension_failures
    union all
    select * from indicator_failures
)

-- Return rows that fail the test (percentages don't sum to 100)
select * from all_failures
