{{ config(
    materialized="view",
    tags=["mart", "dimension", "semantic_layer"]
) }}

with snapshot_dates as (
    select distinct
        date_trunc('day', snapshot_ts)::date as date_day
    from {{ ref('stg_snapshot') }}
    where snapshot_ts is not null
),

time_spine as (
    select
        date_day,

        -- Date parts
        extract(year from date_day) as year,
        extract(quarter from date_day) as quarter,
        extract(month from date_day) as month,
        extract(week from date_day) as week,
        extract(day from date_day) as day,
        extract(dow from date_day) as day_of_week,
        extract(doy from date_day) as day_of_year,

        -- Date labels
        to_char(date_day, 'YYYY-MM') as year_month,
        to_char(date_day, 'YYYY-Q"Q"') as year_quarter,
        to_char(date_day, 'Month') as month_name,
        to_char(date_day, 'Day') as day_name,

        -- Flags
        case when extract(dow from date_day) in (0, 6) then true else false end as is_weekend

    from snapshot_dates
)

select * from time_spine
