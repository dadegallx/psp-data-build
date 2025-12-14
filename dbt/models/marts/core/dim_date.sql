with date_spine as (
    select
        date_day::date as date_actual
    from generate_series(
        '2011-01-01'::date,
        '2035-12-31'::date,
        '1 day'::interval
    ) as date_day
),

date_attributes as (
    select
        -- Surrogate key in YYYYMMDD format
        to_char(date_actual, 'YYYYMMDD')::integer as date_key,

        -- Natural key
        date_actual,

        -- Day attributes
        to_char(date_actual, 'Day') as day_of_week,
        extract(isodow from date_actual)::smallint as day_of_week_number,
        extract(day from date_actual)::smallint as day_of_month,
        extract(doy from date_actual)::smallint as day_of_year,

        -- Week attributes
        extract(week from date_actual)::smallint as week_of_year,

        -- Month attributes
        extract(month from date_actual)::smallint as month_number,
        to_char(date_actual, 'Month') as month_name,
        to_char(date_actual, 'Mon') as month_abbr,

        -- Quarter attributes
        extract(quarter from date_actual)::smallint as quarter_number,
        'Q' || extract(quarter from date_actual)::text as quarter_name,

        -- Year attributes
        extract(year from date_actual)::smallint as year_number,
        extract(year from date_actual)::text || '-Q' || extract(quarter from date_actual)::text as year_quarter,
        to_char(date_actual, 'YYYY-MM') as year_month,

        -- Boolean flags
        case
            when extract(isodow from date_actual) in (6, 7) then true
            else false
        end as is_weekend

    from date_spine
)

select * from date_attributes
