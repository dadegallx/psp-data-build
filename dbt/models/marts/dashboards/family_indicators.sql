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
-- Wide, denormalized mart for Tableau visualization with zero joins required.
-- Grain: Family × Indicator × Snapshot (latest only).
--
-- USAGE IN TABLEAU:
-- - Group by indicator_name for cross-survey aggregation (e.g., "Income")
-- - Drill down with survey_indicator_* fields for localized details
-- - Filter by organization, country, date attributes
-- - No joins needed - all attributes pre-joined
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
        -- SNAPSHOT ATTRIBUTES
        -- ====================================================================
        fact.snapshot_id,
        fact.snapshot_number,

        -- ====================================================================
        -- DATE ATTRIBUTES
        -- ====================================================================
        dim_date.date_actual as snapshot_date,
        dim_date.year_number as snapshot_year,
        dim_date.quarter_number as snapshot_quarter,
        dim_date.month_number as snapshot_month,

        -- ====================================================================
        -- FAMILY ATTRIBUTES
        -- ====================================================================
        dim_family.family_id,
        dim_family.family_code,
        dim_family.family_name,
        dim_family.is_anonymous,
        dim_family.latitude,
        dim_family.longitude,
        dim_family.country_code as family_country_code,

        -- ====================================================================
        -- ORGANIZATION ATTRIBUTES
        -- ====================================================================
        dim_organization.organization_id,
        dim_organization.organization_name,
        dim_organization.organization_country_code,
        dim_organization.application_id,
        dim_organization.application_name,
        dim_organization.application_country_code,

        -- ====================================================================
        -- SURVEY ATTRIBUTES
        -- ====================================================================
        dim_survey_definition.survey_definition_id,
        dim_survey_definition.survey_title,

        -- ====================================================================
        -- MASTER INDICATOR ATTRIBUTES (for aggregation - English)
        -- ====================================================================
        dim_indicator.indicator_name,           -- Primary field for dashboards: "Income"
        dim_indicator.dimension_name,           -- Poverty dimension category

        -- ====================================================================
        -- SURVEY INDICATOR ATTRIBUTES (for drill-down - localized)
        -- ====================================================================
        dim_indicator.survey_indicator_short_name,      -- "Ingresos", "Renda"
        dim_indicator.survey_indicator_question_text,   -- Full translated question
        dim_indicator.survey_indicator_description,     -- Translated description

        -- ====================================================================
        -- MEASURE
        -- ====================================================================
        fact.indicator_status_value             -- 1=Red, 2=Yellow, 3=Green, NULL=Skipped

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
