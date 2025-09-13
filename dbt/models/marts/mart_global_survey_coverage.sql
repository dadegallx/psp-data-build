{{
  config(
    materialized = 'table',
    indexes = [
      {'columns': ['application_id'], 'unique': false},
      {'columns': ['organization_id'], 'unique': true},
      {'columns': ['country_code'], 'unique': false}
    ]
  )
}}

/*
  Global Survey Coverage Mart

  Purpose: Track survey deployment and family engagement across all hubs and organizations

  Grain: One row per organization

  Key Metrics:
  - Family enrollment and survey participation rates
  - Follow-up survey completion rates
  - Survey activity timing and frequency
  - Days between consecutive snapshots per family

  Business Logic:
  - snapshot_number = 1: Baseline survey
  - snapshot_number > 1: Follow-up surveys
  - snapshot_date stored as bigint seconds, converted to timestamp
  - Handles organizations with no families or surveys
*/

WITH organization_base AS (
  SELECT
    o.id AS organization_id,
    o.name AS organization_name,
    o.country_code,
    o.application_id,
    a.name AS application_name
  FROM {{ source('ps_network', 'organizations') }} o
  LEFT JOIN {{ source('ps_network', 'applications') }} a
    ON o.application_id = a.id
),

family_summary AS (
  SELECT
    f.organization_id,
    COUNT(DISTINCT f.family_id) AS total_families
  FROM {{ source('ps_families', 'family') }} f
  GROUP BY f.organization_id
),

snapshot_base AS (
  SELECT
    s.id AS snapshot_id,
    s.family_id,
    s.snapshot_date,
    s.snapshot_number,
    f.organization_id,
    TO_TIMESTAMP(s.snapshot_date) AS snapshot_timestamp
  FROM {{ source('data_collect', 'snapshot') }} s
  INNER JOIN {{ source('ps_families', 'family') }} f
    ON s.family_id = f.family_id
),

snapshot_metrics AS (
  SELECT
    organization_id,
    COUNT(DISTINCT snapshot_id) AS total_snapshots,
    COUNT(DISTINCT family_id) AS families_with_any_survey,
    COUNT(DISTINCT CASE WHEN snapshot_number = 1 THEN family_id END) AS families_with_baseline,
    COUNT(DISTINCT CASE WHEN snapshot_number > 1 THEN family_id END) AS families_with_followup_snapshots,
    MIN(snapshot_timestamp) AS first_survey_date,
    MAX(snapshot_timestamp) AS last_survey_date
  FROM snapshot_base
  GROUP BY organization_id
),

family_followup_check AS (
  SELECT
    organization_id,
    family_id,
    MAX(snapshot_number) AS max_snapshot_number
  FROM snapshot_base
  GROUP BY organization_id, family_id
),

followup_families AS (
  SELECT
    organization_id,
    COUNT(DISTINCT family_id) AS families_with_followup
  FROM family_followup_check
  WHERE max_snapshot_number > 1
  GROUP BY organization_id
),

family_snapshot_intervals AS (
  SELECT
    sb1.organization_id,
    sb1.family_id,
    sb1.snapshot_timestamp,
    sb1.snapshot_number,
    LAG(sb1.snapshot_timestamp) OVER (
      PARTITION BY sb1.family_id
      ORDER BY sb1.snapshot_number
    ) AS prev_snapshot_timestamp
  FROM snapshot_base sb1
),

avg_days_between AS (
  SELECT
    organization_id,
    AVG(
      EXTRACT(EPOCH FROM (snapshot_timestamp - prev_snapshot_timestamp)) / 86400
    ) AS avg_days_between_snapshots
  FROM family_snapshot_intervals
  WHERE prev_snapshot_timestamp IS NOT NULL
  GROUP BY organization_id
)

SELECT
  ob.application_id,
  ob.application_name,
  ob.organization_id,
  ob.organization_name,
  ob.country_code,

  -- Family counts
  COALESCE(fs.total_families, 0) AS total_families,
  COALESCE(sm.families_with_baseline, 0) AS families_with_baseline,
  COALESCE(ff.families_with_followup, 0) AS families_with_followup,

  -- Follow-up rate calculation
  CASE
    WHEN COALESCE(sm.families_with_baseline, 0) = 0 THEN NULL
    ELSE ROUND(
      COALESCE(ff.families_with_followup, 0)::decimal /
      NULLIF(sm.families_with_baseline, 0),
      4
    )
  END AS followup_rate,

  -- Snapshot counts and averages
  COALESCE(sm.total_snapshots, 0) AS total_snapshots,
  CASE
    WHEN COALESCE(fs.total_families, 0) = 0 THEN NULL
    ELSE ROUND(
      COALESCE(sm.total_snapshots, 0)::decimal /
      NULLIF(fs.total_families, 0),
      2
    )
  END AS avg_snapshots_per_family,

  -- Date metrics
  sm.first_survey_date::date AS first_survey_date,
  sm.last_survey_date::date AS last_survey_date,
  CASE
    WHEN sm.last_survey_date IS NULL THEN NULL
    ELSE CURRENT_DATE - sm.last_survey_date::date
  END AS days_since_last_activity,

  -- Average days between snapshots
  ROUND(COALESCE(adb.avg_days_between_snapshots, 0), 1) AS avg_days_between_snapshots

FROM organization_base ob
LEFT JOIN family_summary fs
  ON ob.organization_id = fs.organization_id
LEFT JOIN snapshot_metrics sm
  ON ob.organization_id = sm.organization_id
LEFT JOIN followup_families ff
  ON ob.organization_id = ff.organization_id
LEFT JOIN avg_days_between adb
  ON ob.organization_id = adb.organization_id

ORDER BY
  ob.application_name,
  ob.organization_name