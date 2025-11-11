{{
  config(
    materialized='view',
    tags=['staging']
  )
}}

-- ==============================================================================
-- stg_survey_stoplight_color
-- ==============================================================================
--
-- Pivots stoplight color criteria from long format (3 rows per indicator) to
-- wide format (1 row with red/yellow/green columns).
--
-- Source: data_collect.survey_stoplight_color
-- Grain: One row per survey-specific indicator
--
-- ==============================================================================

with source as (
    select * from {{ source('data_collect', 'survey_stoplight_color') }}
),

pivoted as (
    select
        survey_stoplight_id as survey_indicator_id,

        -- Pivot color descriptions from rows to columns
        max(case when value = 1 then description end) as red_criteria_description,
        max(case when value = 2 then description end) as yellow_criteria_description,
        max(case when value = 3 then description end) as green_criteria_description

    from source
    where value in (1, 2, 3)  -- Only valid stoplight values
    group by survey_stoplight_id
)

select * from pivoted
