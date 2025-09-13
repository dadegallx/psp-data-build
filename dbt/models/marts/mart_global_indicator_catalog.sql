{{
  config(
    materialized = 'view',
    indexes = [
      {'columns': ['indicator_code'], 'unique': true},
      {'columns': ['dimension'], 'unique': false},
      {'columns': ['hubs_using_count'], 'unique': false}
    ]
  )
}}

/*
  Global Indicator Catalog Mart - OPTIMIZED VERSION

  Purpose: Master inventory of all poverty indicators and their global performance metrics

  Grain: One row per unique indicator template

  Key Metrics:
  - Indicator usage across hubs and organizations
  - Global stoplight distribution rates (red/yellow/green)
  - Family improvement rates over time
  - Priority selection frequencies

  Business Logic:
  - Stoplight values: 1=red (critical poverty), 2=yellow (moderate poverty), 3=green (non-poor)
  - Improvement rate: Families whose latest value > first value / families with 2+ measurements
  - Joins through survey_stoplight table to connect templates with responses
  - Handles indicators that may not have responses or priorities

  Performance Optimizations:
  - Consolidated joins to reduce table scans
  - Pre-filtered data for valid stoplight values
  - Simplified window function usage
  - Added strategic indexes
*/

-- OPTIMIZED VERSION - Built from working test model pattern
WITH base_indicators AS (
  SELECT
    ssi.id,
    ssi.code_name,
    ssi.met_short_name,
    ssi.survey_dimension_id
  FROM {{ source('data_collect', 'survey_stoplight_indicator') }} ssi
),

-- Survey implementations count
survey_variations AS (
  SELECT
    ssi.id,
    COUNT(DISTINCT ss.id) AS total_variations
  FROM base_indicators ssi
  LEFT JOIN {{ source('data_collect', 'survey_stoplight') }} ss
    ON ssi.id = ss.survey_indicator_id
  GROUP BY ssi.id
),

-- Combined response data with all needed metrics
-- DEVELOPMENT SAMPLING: Remove TABLESAMPLE for production use
combined_responses AS (
  SELECT
    ssi.id,
    sns.value,
    s.family_id,
    s.snapshot_number,
    o.application_id,
    sns.id AS snapshot_stoplight_id,
    ssp.id AS priority_id
  FROM base_indicators ssi
  LEFT JOIN {{ source('data_collect', 'survey_stoplight') }} ss
    ON ssi.id = ss.survey_indicator_id
  LEFT JOIN {{ source('data_collect', 'snapshot_stoplight') }} sns TABLESAMPLE SYSTEM (10)  -- Sample 10% for development
    ON ss.code_name = sns.code_name
    AND sns.value IN (1, 2, 3)  -- Only valid responses
  LEFT JOIN {{ source('data_collect', 'snapshot') }} s
    ON sns.snapshot_id = s.id
  LEFT JOIN {{ source('ps_families', 'family') }} f
    ON s.family_id = f.family_id
  LEFT JOIN {{ source('ps_network', 'organizations') }} o
    ON f.organization_id = o.id
  LEFT JOIN {{ source('data_collect', 'snapshot_stoplight_priority') }} ssp
    ON sns.id = ssp.snapshot_stoplight_id
),

-- Hub usage metrics
hub_usage AS (
  SELECT
    id,
    COUNT(DISTINCT application_id) AS hubs_using_count
  FROM combined_responses
  WHERE application_id IS NOT NULL
  GROUP BY id
),

-- Basic response metrics
response_metrics AS (
  SELECT
    id,
    COUNT(CASE WHEN value IS NOT NULL THEN 1 END) AS total_responses,
    COUNT(DISTINCT CASE WHEN value IS NOT NULL THEN family_id END) AS families_measured,
    COUNT(CASE WHEN value = 1 THEN 1 END) AS red_responses,
    COUNT(CASE WHEN value = 2 THEN 1 END) AS yellow_responses,
    COUNT(CASE WHEN value = 3 THEN 1 END) AS green_responses
  FROM combined_responses
  GROUP BY id
),

-- Improvement analysis with row numbers
family_progress AS (
  SELECT
    id,
    family_id,
    value,
    snapshot_number,
    ROW_NUMBER() OVER (PARTITION BY id, family_id ORDER BY snapshot_number ASC) AS first_rank,
    ROW_NUMBER() OVER (PARTITION BY id, family_id ORDER BY snapshot_number DESC) AS last_rank
  FROM combined_responses
  WHERE value IS NOT NULL
),

improvement_rates AS (
  SELECT
    first_measure.id,
    COUNT(*) AS families_with_multiple_measurements,
    COUNT(CASE WHEN last_measure.value > first_measure.value THEN 1 END) AS families_improved
  FROM family_progress first_measure
  INNER JOIN family_progress last_measure
    ON first_measure.id = last_measure.id
    AND first_measure.family_id = last_measure.family_id
  WHERE first_measure.first_rank = 1
    AND last_measure.last_rank = 1
    AND first_measure.snapshot_number != last_measure.snapshot_number
  GROUP BY first_measure.id
),

-- Priority metrics
priority_metrics AS (
  SELECT
    id,
    COUNT(DISTINCT priority_id) AS priority_selections,
    COUNT(DISTINCT snapshot_stoplight_id) AS total_response_opportunities
  FROM combined_responses
  WHERE snapshot_stoplight_id IS NOT NULL
  GROUP BY id
)

SELECT
  bi.code_name AS indicator_code,
  bi.met_short_name AS indicator_short_name,
  COALESCE(bi.survey_dimension_id::text, 'Unknown') AS dimension,

  -- Usage metrics
  COALESCE(hu.hubs_using_count, 0) AS hubs_using_count,
  COALESCE(sv.total_variations, 0) AS total_variations,

  -- Response metrics
  COALESCE(rm.total_responses, 0) AS total_responses,
  COALESCE(rm.families_measured, 0) AS families_measured,

  -- Stoplight distribution rates
  CASE
    WHEN COALESCE(rm.total_responses, 0) = 0 THEN NULL
    ELSE ROUND(
      COALESCE(rm.red_responses, 0)::decimal /
      NULLIF(rm.total_responses, 0),
      4
    )
  END AS global_red_rate,

  CASE
    WHEN COALESCE(rm.total_responses, 0) = 0 THEN NULL
    ELSE ROUND(
      COALESCE(rm.yellow_responses, 0)::decimal /
      NULLIF(rm.total_responses, 0),
      4
    )
  END AS global_yellow_rate,

  CASE
    WHEN COALESCE(rm.total_responses, 0) = 0 THEN NULL
    ELSE ROUND(
      COALESCE(rm.green_responses, 0)::decimal /
      NULLIF(rm.total_responses, 0),
      4
    )
  END AS global_green_rate,

  -- Improvement rate
  CASE
    WHEN COALESCE(ir.families_with_multiple_measurements, 0) = 0 THEN NULL
    ELSE ROUND(
      COALESCE(ir.families_improved, 0)::decimal /
      NULLIF(ir.families_with_multiple_measurements, 0),
      4
    )
  END AS improvement_rate,

  -- Priority selection rate
  CASE
    WHEN COALESCE(pm.total_response_opportunities, 0) = 0 THEN NULL
    ELSE ROUND(
      COALESCE(pm.priority_selections, 0)::decimal /
      NULLIF(pm.total_response_opportunities, 0),
      4
    )
  END AS priority_selection_rate

FROM base_indicators bi
LEFT JOIN survey_variations sv
  ON bi.id = sv.id
LEFT JOIN hub_usage hu
  ON bi.id = hu.id
LEFT JOIN response_metrics rm
  ON bi.id = rm.id
LEFT JOIN improvement_rates ir
  ON bi.id = ir.id
LEFT JOIN priority_metrics pm
  ON bi.id = pm.id

ORDER BY
  bi.code_name