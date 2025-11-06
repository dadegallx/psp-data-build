{{
  config(
    materialized='table',
    tags=['semantic_layer', 'time_spine']
  )
}}

/*
Time Spine Model for MetricFlow

This model creates a comprehensive date dimension with multiple granularities
to support time-based metric calculations and date range queries.

Adjust start_date and end_date based on your data range:
- start_date: Set to earliest date in your data (or earlier)
- end_date: Set to extend beyond current date (typically +1 year)
*/

with date_spine as (
    {{ dbt.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="cast(current_date + interval '1 year' as date)"
    ) }}
),

date_attributes as (
    select
        -- Primary date key (daily granularity)
        date_day,

        -- Week aggregations
        date_trunc('week', date_day) as date_week,

        -- Month aggregations
        date_trunc('month', date_day) as date_month,

        -- Quarter aggregations
        date_trunc('quarter', date_day) as date_quarter,

        -- Year aggregations
        date_trunc('year', date_day) as date_year,

        -- Additional date attributes (optional)
        extract(year from date_day) as year_number,
        extract(quarter from date_day) as quarter_number,
        extract(month from date_day) as month_number,
        extract(week from date_day) as week_number,
        extract(day from date_day) as day_of_month,
        extract(dow from date_day) as day_of_week,
        extract(doy from date_day) as day_of_year,

        -- Helper flags (optional)
        case when extract(dow from date_day) in (0, 6) then true else false end as is_weekend,
        case when date_day = current_date then true else false end as is_today

    from date_spine
)

select * from date_attributes
