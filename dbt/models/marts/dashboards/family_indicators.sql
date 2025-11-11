{{
  config(
    materialized='table',
    tags=['mart', 'dashboard', 'denormalized']
  )
}}

-- ==============================================================================
-- family_indicators
-- ==============================================================================
--
-- Simplified, business-user-friendly dashboard for poverty indicator analysis.
-- Laser-focused on indicators with easy-to-use boolean flags for BI tools.
--
-- Grain: Family × Indicator × Snapshot (latest only)
-- Columns: 17 (down from 23) - removed technical/privacy fields
--
-- BUSINESS USER FEATURES:
-- ✅ Easy counting: SUM(is_red::int), SUM(is_yellow::int), SUM(is_green::int)
-- ✅ Easy percentages: AVG(is_red::int) * 100
-- ✅ Easy filtering: WHERE is_red = TRUE
-- ✅ Clear status flags: is_red, is_yellow, is_green, is_skipped
--
-- SUPERSET/TABLEAU USAGE:
-- - Red indicator count: SUM(is_red::int) or COUNT(*) FILTER (WHERE is_red)
-- - Most critical indicators: GROUP BY indicator_name, ORDER BY SUM(is_red::int) DESC
-- - Progress tracking: Compare SUM(is_green::int) over time
-- - Dimension analysis: GROUP BY dimension_name, calculate % red/yellow/green
--
-- ==============================================================================

with fact as (
    select * from {{ ref('fact_family_indicator_snapshot') }}
    where is_last = true  -- Latest snapshots only (current family status)
),

dim_date as (
    select * from {{ ref('dim_date') }}
),

dim_family as (
    select * from {{ ref('dim_family') }}
),

dim_organization as (
    select * from {{ ref('dim_organization') }}
),

dim_indicator as (
    select * from {{ ref('dim_indicator') }}
),

dim_survey_definition as (
    select * from {{ ref('dim_survey_definition') }}
),

denormalized as (
    select
        -- ====================================================================
        -- DATE ATTRIBUTES (4 columns)
        -- ====================================================================
        dim_date.date_actual as snapshot_date,
        dim_date.year_number as snapshot_year,
        dim_date.quarter_number as snapshot_quarter,
        dim_date.month_number as snapshot_month,

        -- ====================================================================
        -- FAMILY IDENTIFIERS (2 columns)
        -- ====================================================================
        dim_family.family_id,
        dim_family.family_code,

        -- ====================================================================
        -- ORGANIZATION CONTEXT (2 columns)
        -- ====================================================================
        dim_organization.organization_name,
        dim_organization.application_name,

        -- ====================================================================
        -- INDICATOR DEFINITION (5 columns)
        -- ====================================================================
        -- Master indicator (for aggregation across surveys - English)
        dim_indicator.indicator_name,           -- Primary: "Income", "Health"
        dim_indicator.dimension_name,           -- Category: "Income and Employment"

        -- Survey-specific indicator (for drill-down - localized)
        dim_indicator.survey_indicator_short_name,      -- Localized: "Ingresos", "Renda"
        dim_indicator.survey_indicator_question_text,   -- Full translated question text
        dim_indicator.survey_indicator_description,     -- Aspirational green-level description

        -- ====================================================================
        -- POVERTY STATUS FLAGS (4 columns) - Easy counting and averaging
        -- ====================================================================
        (fact.indicator_status_value = 1) as is_red,        -- Critical poverty/unmet need
        (fact.indicator_status_value = 2) as is_yellow,     -- Moderate poverty/vulnerability
        (fact.indicator_status_value = 3) as is_green,      -- Non-poor/need met
        (fact.indicator_status_value not in (1, 2, 3) or fact.indicator_status_value is null) as is_skipped -- Not assessed/not applicable/invalid

    from fact
    inner join dim_date
        on fact.date_key = dim_date.date_key
    inner join dim_family
        on fact.family_key = dim_family.family_key
    inner join dim_organization
        on fact.organization_key = dim_organization.organization_key
    inner join dim_indicator
        on fact.indicator_key = dim_indicator.indicator_key
    inner join dim_survey_definition
        on fact.survey_definition_key = dim_survey_definition.survey_definition_key
)

select * from denormalized
