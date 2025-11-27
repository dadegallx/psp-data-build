-- View for lightweight organization-scoped filtering
{{ config(materialized='view') }}

-- ==============================================================================
-- family_indicators_unbound_honduras
-- ==============================================================================
--
-- Organization-scoped dashboard dataset for Unbound honduras organization.
-- Filtered subset of family_indicators for improved business user experience.
--
-- ORGANIZATION STATS:
-- - Organization: Unbound honduras (unbound_hon_hub application)
-- - Families: 231
-- - Indicators: 50 (perfect target for standard survey)
-- - Records: 11,550
-- - Data Completeness: 100%
--
-- USAGE:
-- - Provides pre-filtered dataset for Unbound Honduras-specific dashboards
-- - Eliminates need for organization filtering in BI tools
-- - Simplifies dashboard development and improves query clarity
-- - All 50 indicators are survey-specific to Unbound Honduras assessment tool
--
-- ==============================================================================

select *
from {{ ref('family_indicators') }}
where organization_name = 'Unbound honduras'
