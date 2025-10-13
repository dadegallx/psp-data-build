{{ config(
    materialized="table",
    tags=["mart", "metricflow"]
) }}

/*
    Time spine model required by MetricFlow for time-based aggregations.
    Generates one row per day from 2000-01-01 to current date + 1 year.

    This model is used by MetricFlow to:
    - Fill in missing dates in time series
    - Support time-based window functions
    - Enable period-over-period comparisons
*/

with date_spine as (
    {{
        dbt_utils.date_spine(
            datepart="day",
            start_date="cast('2000-01-01' as date)",
            end_date="cast(dateadd(year, 1, current_date) as date)"
        )
    }}
)

select
    date_day
from date_spine
