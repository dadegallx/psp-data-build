{{ config(materialized='view') }}

-- Simple test version of the indicator catalog
SELECT
  ssi.id AS template_id,
  ssi.code_name AS indicator_code,
  ssi.met_short_name AS indicator_short_name,
  COUNT(DISTINCT ss.id) AS total_variations,
  COUNT(DISTINCT CASE WHEN sns.value IN (1,2,3) THEN sns.id END) AS total_responses,
  COUNT(DISTINCT CASE WHEN sns.value IN (1,2,3) THEN s.family_id END) AS families_measured
FROM {{ source('data_collect', 'survey_stoplight_indicator') }} ssi
LEFT JOIN {{ source('data_collect', 'survey_stoplight') }} ss
  ON ssi.id = ss.survey_indicator_id
LEFT JOIN {{ source('data_collect', 'snapshot_stoplight') }} sns
  ON ss.code_name = sns.code_name
LEFT JOIN {{ source('data_collect', 'snapshot') }} s
  ON sns.snapshot_id = s.id
GROUP BY ssi.id, ssi.code_name, ssi.met_short_name
ORDER BY ssi.code_name
LIMIT 20