-- View for lightweight organization-scoped filtering
{{ config(materialized='view') }}

-- ==============================================================================
-- family_indicators_empresas_semaforo
-- ==============================================================================
--
-- Organization-scoped dashboard dataset for Empresas del Semáforo Paraguay.
-- Filtered subset of family_indicators for improved business user experience.
--
-- ORGANIZATION STATS:
-- - Organization: Empresas del Semáforo Paraguay (hub application)
-- - Families: 97
-- - Indicators: 51 (perfect target for standard survey)
-- - Records: 4,947
-- - Data Completeness: 100%
--
-- USAGE:
-- - Provides pre-filtered dataset for Empresas del Semáforo-specific dashboards
-- - Eliminates need for organization filtering in BI tools
-- - Simplifies dashboard development and improves query clarity
-- - All 51 indicators are survey-specific to Empresas del Semáforo assessment tool
--
-- ==============================================================================

select *
from {{ ref('family_indicators') }}
where organization_name = 'Empresas del Semáforo Paraguay'
