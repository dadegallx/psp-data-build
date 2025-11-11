{{
  config(
    materialized='view',
    tags=['mart', 'dashboard', 'organization_scoped']
  )
}}

-- ==============================================================================
-- family_indicators_signal
-- ==============================================================================
--
-- Organization-scoped dashboard dataset for Signal organization.
-- Filtered subset of family_indicators for improved business user experience.
--
-- ORGANIZATION STATS:
-- - Organization: Signal (hub application)
-- - Families: 967
-- - Indicators: 55
-- - Records: 45,358
-- - Data Completeness: 100%
--
-- USAGE:
-- - Provides pre-filtered dataset for Signal-specific dashboards
-- - Eliminates need for organization filtering in BI tools
-- - Simplifies dashboard development and improves query clarity
-- - All 55 indicators are survey-specific to Signal's assessment tool
--
-- ==============================================================================

select *
from {{ ref('family_indicators') }}
where organization_name = 'Signal'
