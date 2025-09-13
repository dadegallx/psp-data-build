{{
  config(
    materialized = 'view'
  )
}}

/*
  Paraguay Family Current State Mart

  Purpose: Current poverty status and progression for each family in Paraguay

  Grain: One row per family

  Key Metrics:
  - Current poverty status (red/yellow/green indicators)
  - Six dimension scores (income, health, housing, education, organization, self-awareness)
  - Poverty score changes and progression tracking
  - Priority selections and intervention focus areas

  Business Logic:
  - Filter: Paraguay families only (country_code = 'PY')
  - Use is_last = true for current family status
  - Convert snapshot_date from bigint milliseconds using TO_TIMESTAMP(snapshot_date/1000)
  - Score calculations: (green×3 + yellow×2 + red×1) / (total×3)
  - Handle families with only 1 snapshot (changes should be NULL)

  Data Sources:
  - ps_families.family: Family records
  - data_collect.snapshot: Survey snapshots
  - data_collect.snapshot_stoplight: Indicator responses
  - data_collect.snapshot_stoplight_priority: Priority selections
  - ps_network.organizations: Organization details
*/

WITH paraguay_families AS (
  SELECT
    f.family_id,
    f.code AS family_code,
    f.anonymous AS is_anonymous,
    f.organization_id,
    o.name AS organization_name
  FROM {{ source('ps_families', 'family') }} f
  INNER JOIN {{ source('ps_network', 'organizations') }} o
    ON f.organization_id = o.id
  WHERE o.country_code = 'PY'
    AND f.is_active = true  -- Only active families
  LIMIT 100  -- Limit for testing
),

family_snapshots AS (
  SELECT
    s.id AS snapshot_id,
    s.family_id,
    s.snapshot_number,
    s.is_last,
    TO_TIMESTAMP(s.snapshot_date/1000.0) AS snapshot_date
  FROM {{ source('data_collect', 'snapshot') }} s
  INNER JOIN paraguay_families pf
    ON s.family_id = pf.family_id
),

-- Baseline snapshots (snapshot_number = 1)
baseline_snapshots AS (
  SELECT
    family_id,
    MIN(snapshot_date) AS first_snapshot_date,
    MIN(snapshot_id) AS baseline_snapshot_id
  FROM family_snapshots
  WHERE snapshot_number = 1
  GROUP BY family_id
),

-- Latest snapshots (is_last = true)
latest_snapshots AS (
  SELECT
    family_id,
    MAX(snapshot_date) AS latest_snapshot_date,
    MAX(snapshot_id) AS latest_snapshot_id
  FROM family_snapshots
  WHERE is_last = true
  GROUP BY family_id
),

-- Family snapshot summary
family_snapshot_summary AS (
  SELECT
    fs.family_id,
    COUNT(DISTINCT fs.snapshot_id) AS total_snapshots,
    bs.first_snapshot_date,
    ls.latest_snapshot_date,
    bs.baseline_snapshot_id,
    ls.latest_snapshot_id,
    ROUND(
      EXTRACT(EPOCH FROM (ls.latest_snapshot_date - bs.first_snapshot_date)) / (30.44 * 24 * 3600),
      1
    ) AS months_since_baseline
  FROM family_snapshots fs
  LEFT JOIN baseline_snapshots bs ON fs.family_id = bs.family_id
  LEFT JOIN latest_snapshots ls ON fs.family_id = ls.family_id
  GROUP BY
    fs.family_id,
    bs.first_snapshot_date,
    ls.latest_snapshot_date,
    bs.baseline_snapshot_id,
    ls.latest_snapshot_id
),

-- Latest snapshot indicators with dimension mapping
latest_indicators AS (
  SELECT
    fss.family_id,
    ss.value,
    ssl.survey_dimension_id,
    ssd.code_name AS dimension_code,
    ssl.survey_indicator_id AS indicator_template_id
  FROM family_snapshot_summary fss
  INNER JOIN {{ source('data_collect', 'snapshot_stoplight') }} ss
    ON fss.latest_snapshot_id = ss.snapshot_id
  INNER JOIN {{ source('data_collect', 'survey_stoplight') }} ssl
    ON ss.code_name = ssl.code_name
  INNER JOIN {{ source('data_collect', 'survey_stoplight_dimension') }} ssd
    ON ssl.survey_dimension_id = ssd.id
),

-- Baseline snapshot indicators for comparison
baseline_indicators AS (
  SELECT
    fss.family_id,
    ss.value,
    ssl.survey_dimension_id,
    ssd.code_name AS dimension_code,
    ssl.survey_indicator_id AS indicator_template_id
  FROM family_snapshot_summary fss
  INNER JOIN {{ source('data_collect', 'snapshot_stoplight') }} ss
    ON fss.baseline_snapshot_id = ss.snapshot_id
  INNER JOIN {{ source('data_collect', 'survey_stoplight') }} ssl
    ON ss.code_name = ssl.code_name
  INNER JOIN {{ source('data_collect', 'survey_stoplight_dimension') }} ssd
    ON ssl.survey_dimension_id = ssd.id
),

-- Aggregate latest indicators by family
latest_indicator_summary AS (
  SELECT
    family_id,
    COUNT(*) AS total_indicators,
    COUNT(CASE WHEN value = 1 THEN 1 END) AS indicators_red,
    COUNT(CASE WHEN value = 2 THEN 1 END) AS indicators_yellow,
    COUNT(CASE WHEN value = 3 THEN 1 END) AS indicators_green,

    -- Overall poverty score
    CASE
      WHEN COUNT(*) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN value = 3 THEN 1 END) * 3.0) /
        (COUNT(*) * 3.0),
        4
      )
    END AS poverty_score,

    -- Dimension scores (using standard 6 dimensions)
    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'incomeAndEmployment' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'incomeAndEmployment' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'incomeAndEmployment' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'incomeAndEmployment' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'incomeAndEmployment' THEN 1 END) * 3.0),
        4
      )
    END AS income_score,

    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'healthAndEnvironment' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'healthAndEnvironment' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'healthAndEnvironment' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'healthAndEnvironment' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'healthAndEnvironment' THEN 1 END) * 3.0),
        4
      )
    END AS health_score,

    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'housingAndInfrastructure' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'housingAndInfrastructure' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'housingAndInfrastructure' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'housingAndInfrastructure' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'housingAndInfrastructure' THEN 1 END) * 3.0),
        4
      )
    END AS housing_score,

    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'educationAndCulture' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'educationAndCulture' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'educationAndCulture' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'educationAndCulture' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'educationAndCulture' THEN 1 END) * 3.0),
        4
      )
    END AS education_score,

    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'organizationAndParticipation' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'organizationAndParticipation' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'organizationAndParticipation' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'organizationAndParticipation' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'organizationAndParticipation' THEN 1 END) * 3.0),
        4
      )
    END AS organization_score,

    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'interiorityAndMotivation' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'interiorityAndMotivation' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'interiorityAndMotivation' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'interiorityAndMotivation' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'interiorityAndMotivation' THEN 1 END) * 3.0),
        4
      )
    END AS self_awareness_score

  FROM latest_indicators
  GROUP BY family_id
),

-- Aggregate baseline indicators by family for comparison
baseline_indicator_summary AS (
  SELECT
    family_id,

    -- Overall baseline poverty score
    CASE
      WHEN COUNT(*) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN value = 3 THEN 1 END) * 3.0) /
        (COUNT(*) * 3.0),
        4
      )
    END AS baseline_poverty_score,

    -- Baseline dimension scores
    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'incomeAndEmployment' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'incomeAndEmployment' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'incomeAndEmployment' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'incomeAndEmployment' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'incomeAndEmployment' THEN 1 END) * 3.0),
        4
      )
    END AS baseline_income_score,

    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'healthAndEnvironment' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'healthAndEnvironment' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'healthAndEnvironment' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'healthAndEnvironment' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'healthAndEnvironment' THEN 1 END) * 3.0),
        4
      )
    END AS baseline_health_score,

    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'housingAndInfrastructure' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'housingAndInfrastructure' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'housingAndInfrastructure' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'housingAndInfrastructure' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'housingAndInfrastructure' THEN 1 END) * 3.0),
        4
      )
    END AS baseline_housing_score,

    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'educationAndCulture' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'educationAndCulture' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'educationAndCulture' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'educationAndCulture' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'educationAndCulture' THEN 1 END) * 3.0),
        4
      )
    END AS baseline_education_score,

    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'organizationAndParticipation' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'organizationAndParticipation' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'organizationAndParticipation' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'organizationAndParticipation' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'organizationAndParticipation' THEN 1 END) * 3.0),
        4
      )
    END AS baseline_organization_score,

    CASE
      WHEN COUNT(CASE WHEN dimension_code = 'interiorityAndMotivation' THEN 1 END) = 0 THEN NULL
      ELSE ROUND(
        (COUNT(CASE WHEN dimension_code = 'interiorityAndMotivation' AND value = 1 THEN 1 END) * 1.0 +
         COUNT(CASE WHEN dimension_code = 'interiorityAndMotivation' AND value = 2 THEN 1 END) * 2.0 +
         COUNT(CASE WHEN dimension_code = 'interiorityAndMotivation' AND value = 3 THEN 1 END) * 3.0) /
        (COUNT(CASE WHEN dimension_code = 'interiorityAndMotivation' THEN 1 END) * 3.0),
        4
      )
    END AS baseline_self_awareness_score

  FROM baseline_indicators
  GROUP BY family_id
),

-- Calculate indicator-level changes
indicator_changes AS (
  SELECT
    li.family_id,
    COUNT(CASE WHEN li.value > bi.value THEN 1 END) AS indicators_improved,
    COUNT(CASE WHEN li.value < bi.value THEN 1 END) AS indicators_declined
  FROM latest_indicators li
  INNER JOIN baseline_indicators bi
    ON li.family_id = bi.family_id
    AND li.indicator_template_id = bi.indicator_template_id
  GROUP BY li.family_id
),

-- Priority selections from latest snapshot
family_priorities AS (
  SELECT
    fss.family_id,
    ARRAY_AGG(ss.code_name ORDER BY ss.code_name) AS priorities_selected,
    COUNT(ssp.id) AS priority_count
  FROM family_snapshot_summary fss
  INNER JOIN {{ source('data_collect', 'snapshot_stoplight') }} ss
    ON fss.latest_snapshot_id = ss.snapshot_id
  INNER JOIN {{ source('data_collect', 'snapshot_stoplight_priority') }} ssp
    ON ss.id = ssp.snapshot_stoplight_id
  GROUP BY fss.family_id
)

SELECT
  pf.family_id,
  pf.family_code,
  pf.organization_name,
  pf.is_anonymous,

  -- Snapshot timing
  fss.first_snapshot_date::date AS first_snapshot_date,
  fss.latest_snapshot_date::date AS latest_snapshot_date,
  fss.total_snapshots,
  fss.months_since_baseline,

  -- Current indicator counts
  COALESCE(lis.total_indicators, 0) AS total_indicators,
  COALESCE(lis.indicators_red, 0) AS indicators_red,
  COALESCE(lis.indicators_yellow, 0) AS indicators_yellow,
  COALESCE(lis.indicators_green, 0) AS indicators_green,

  -- Current scores
  lis.poverty_score,
  lis.income_score,
  lis.health_score,
  lis.housing_score,
  lis.education_score,
  lis.organization_score,
  lis.self_awareness_score,

  -- Score changes (only for families with 2+ snapshots)
  CASE
    WHEN fss.total_snapshots > 1 THEN ROUND(lis.poverty_score - bis.baseline_poverty_score, 4)
    ELSE NULL
  END AS poverty_score_change,

  CASE
    WHEN fss.total_snapshots > 1 THEN ROUND(lis.income_score - bis.baseline_income_score, 4)
    ELSE NULL
  END AS income_score_change,

  CASE
    WHEN fss.total_snapshots > 1 THEN ROUND(lis.health_score - bis.baseline_health_score, 4)
    ELSE NULL
  END AS health_score_change,

  CASE
    WHEN fss.total_snapshots > 1 THEN ROUND(lis.housing_score - bis.baseline_housing_score, 4)
    ELSE NULL
  END AS housing_score_change,

  CASE
    WHEN fss.total_snapshots > 1 THEN ROUND(lis.education_score - bis.baseline_education_score, 4)
    ELSE NULL
  END AS education_score_change,

  CASE
    WHEN fss.total_snapshots > 1 THEN ROUND(lis.organization_score - bis.baseline_organization_score, 4)
    ELSE NULL
  END AS organization_score_change,

  CASE
    WHEN fss.total_snapshots > 1 THEN ROUND(lis.self_awareness_score - bis.baseline_self_awareness_score, 4)
    ELSE NULL
  END AS self_awareness_score_change,

  -- Indicator improvement tracking
  COALESCE(ic.indicators_improved, 0) AS indicators_improved,
  COALESCE(ic.indicators_declined, 0) AS indicators_declined,

  -- Priorities
  fp.priorities_selected,
  COALESCE(fp.priority_count, 0) AS priority_count

FROM paraguay_families pf
INNER JOIN family_snapshot_summary fss
  ON pf.family_id = fss.family_id
LEFT JOIN latest_indicator_summary lis
  ON pf.family_id = lis.family_id
LEFT JOIN baseline_indicator_summary bis
  ON pf.family_id = bis.family_id
LEFT JOIN indicator_changes ic
  ON pf.family_id = ic.family_id
LEFT JOIN family_priorities fp
  ON pf.family_id = fp.family_id

ORDER BY
  pf.organization_name,
  pf.family_code