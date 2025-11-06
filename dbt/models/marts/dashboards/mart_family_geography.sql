{{
  config(
    materialized='table',
    tags=['mart', 'dashboard', 'geography', 'map']
  )
}}

with latest_metrics as (
    select * from {{ ref('int_latest_metrics') }}
),

geography_with_status as (
    select
        -- Family identifiers
        family_id,
        family_code,
        family_name,

        -- Geographic coordinates
        latitude,
        longitude,
        country_code,

        -- Indicator attributes
        indicator_id,
        indicator_short_name,
        indicator_code_name,
        dimension_name,

        -- Organization attributes
        organization_id,
        organization_name,
        application_id,
        application_name,

        -- Survey attributes
        survey_definition_id,
        survey_title,

        -- Date attributes
        snapshot_date,
        snapshot_year,
        snapshot_quarter,
        snapshot_month,

        -- Snapshot attributes
        snapshot_id,
        snapshot_number,

        -- Status value
        indicator_status_value,

        -- Status label
        case
            when indicator_status_value = 3 then 'Green'
            when indicator_status_value = 2 then 'Yellow'
            when indicator_status_value = 1 then 'Red'
            else 'Skipped'
        end as indicator_status_label,

        -- Status color for map visualization
        case
            when indicator_status_value = 3 then '#00FF00'  -- Green
            when indicator_status_value = 2 then '#FFFF00'  -- Yellow
            when indicator_status_value = 1 then '#FF0000'  -- Red
            else '#CCCCCC'  -- Gray for skipped
        end as indicator_status_color_hex

    from latest_metrics
    where latitude is not null
      and longitude is not null  -- Only include families with valid GPS coordinates
),

final as (
    select
        -- Family identifiers
        family_id,
        family_code,
        family_name,

        -- Geographic attributes (for map)
        latitude,
        longitude,
        country_code,

        -- Indicator attributes (for filtering)
        indicator_id,
        indicator_short_name,
        indicator_code_name,
        dimension_name,

        -- Organization attributes (for filtering)
        organization_id,
        organization_name,
        application_id,
        application_name,

        -- Survey attributes
        survey_definition_id,
        survey_title,

        -- Date attributes (for filtering)
        snapshot_date,
        snapshot_year,
        snapshot_quarter,
        snapshot_month,

        -- Snapshot attributes
        snapshot_id,
        snapshot_number,

        -- Status attributes
        indicator_status_value,
        indicator_status_label,
        indicator_status_color_hex

    from geography_with_status
)

select * from final
