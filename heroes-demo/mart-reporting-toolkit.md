# Mart Reporting Toolkit

Focus on the questions that decision-makers raise most often. Use these ready-to-run queries together with the recommended visuals to guide conversations.

---

## Platform Pulse (Whole Dataset)

### Current Families With a Valid Snapshot

**Question** — How many families across the network currently have an up-to-date snapshot on record?  
**Recommended visualization** — KPI card; track the headline count over time.

```sql
SELECT COUNT(DISTINCT family_id) AS active_families_current
FROM mart_marts.mart_snapshot_current;
```

**Breakdown by organization and hub (application)** — horizontal bar chart sorted descending.

```sql
SELECT
  sc.organization_id,
  org.organization_name,
  sc.application_id,
  app.application_name,
  COUNT(DISTINCT sc.family_id) AS active_families_current
FROM mart_marts.mart_snapshot_current sc
LEFT JOIN mart_marts.dim_organization org
  ON sc.organization_id = org.organization_id
LEFT JOIN mart_marts.dim_application app
  ON sc.application_id = app.application_id
GROUP BY 1, 2, 3, 4
ORDER BY active_families_current DESC;
```

---

### Families Completing a Follow-up Survey

**Question** — How many families have progressed beyond their baseline and submitted at least one follow-up snapshot?  
**Recommended visualization** — KPI card paired with the baseline total for context.

```sql
SELECT COUNT(DISTINCT family_id) AS families_with_followup
FROM mart_marts.fact_snapshot
WHERE snapshot_number > 1;
```

**Breakdown by organization and hub** — clustered columns comparing follow-up traction across teams.

```sql
SELECT
  fs.organization_id,
  org.organization_name,
  fs.application_id,
  app.application_name,
  COUNT(DISTINCT fs.family_id) AS families_with_followup
FROM mart_marts.fact_snapshot fs
LEFT JOIN mart_marts.dim_organization org
  ON fs.organization_id = org.organization_id
LEFT JOIN mart_marts.dim_application app
  ON fs.application_id = app.application_id
WHERE fs.snapshot_number > 1
GROUP BY 1, 2, 3, 4
ORDER BY families_with_followup DESC;
```

---

### Baseline vs. Follow-up Mix

**Question** — Of the families with a baseline, how many remain baseline-only versus those that reached at least one follow-up?  
**Recommended visualization** — donut chart showing the split between “baseline only” and “baseline + follow-up”.

```sql
WITH baseline AS (
  SELECT DISTINCT family_id
  FROM mart_marts.mart_snapshot_baseline
),
followup AS (
  SELECT DISTINCT family_id
  FROM mart_marts.fact_snapshot
  WHERE snapshot_number > 1
)
SELECT
  COUNT(*) FILTER (WHERE f.family_id IS NULL) AS baseline_only_families,
  COUNT(*) FILTER (WHERE f.family_id IS NOT NULL) AS baseline_with_followup_families
FROM baseline b
LEFT JOIN followup f USING (family_id);
```

**Breakdown by organization and hub** — stacked bar chart per team showing the two categories.

```sql
WITH baseline AS (
  SELECT DISTINCT family_id, organization_id, application_id
  FROM mart_marts.mart_snapshot_baseline
),
followup AS (
  SELECT DISTINCT family_id
  FROM mart_marts.fact_snapshot
  WHERE snapshot_number > 1
)
SELECT
  b.organization_id,
  org.organization_name,
  b.application_id,
  app.application_name,
  COUNT(*) FILTER (WHERE f.family_id IS NULL) AS baseline_only_families,
  COUNT(*) FILTER (WHERE f.family_id IS NOT NULL) AS baseline_with_followup_families
FROM baseline b
LEFT JOIN followup f USING (family_id)
LEFT JOIN mart_marts.dim_organization org ON org.organization_id = b.organization_id
LEFT JOIN mart_marts.dim_application app ON app.application_id = b.application_id
GROUP BY 1, 2, 3, 4
ORDER BY baseline_with_followup_families DESC;
```

---

### Anonymous Snapshot Share

**Question** — What portion of current snapshots are anonymous, and how does that vary by hub?  
**Recommended visualization** — overall donut chart plus a horizontal bar chart by hub.

```sql
SELECT
  SUM(CASE WHEN anonymous THEN 1 ELSE 0 END) * 1.0 / NULLIF(COUNT(*), 0) AS share_anonymous_current
FROM mart_marts.mart_snapshot_current;
```

**Breakdown by hub (application)** — highlight applications where anonymity is more prevalent.

```sql
SELECT
  sc.application_id,
  app.application_name,
  SUM(CASE WHEN sc.anonymous THEN 1 ELSE 0 END) AS anonymous_snapshots,
  COUNT(*) AS total_snapshots,
  SUM(CASE WHEN sc.anonymous THEN 1 ELSE 0 END) * 1.0 / NULLIF(COUNT(*), 0) AS share_anonymous
FROM mart_marts.mart_snapshot_current sc
LEFT JOIN mart_marts.dim_application app USING (application_id)
GROUP BY 1, 2
ORDER BY share_anonymous DESC;
```

---

### Snapshot Cadence

**Question** — What is the typical cadence between snapshots, and does the speed differ across teams?  
**Recommended visualization** — KPI card showing median days (with average as a secondary metric); optional scatter or box plot by organization.

```sql
SELECT
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_since_prev) AS median_days_between,
  AVG(days_since_prev) AS avg_days_between
FROM mart_marts.fact_snapshot
WHERE days_since_prev IS NOT NULL;
```

**Breakdown by organization and hub** — surface teams that are faster or slower than the network median.

```sql
SELECT
  fs.organization_id,
  org.organization_name,
  fs.application_id,
  app.application_name,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY fs.days_since_prev) AS median_days_between,
  AVG(fs.days_since_prev) AS avg_days_between
FROM mart_marts.fact_snapshot fs
LEFT JOIN mart_marts.dim_organization org USING (organization_id)
LEFT JOIN mart_marts.dim_application app USING (application_id)
WHERE fs.days_since_prev IS NOT NULL
GROUP BY 1, 2, 3, 4
ORDER BY median_days_between;
```

---

## Semáforo Héroes Demo (Survey Definition “Semáforo Héroes”)

Use the shared survey filter CTE in each query to target the demo dataset.

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
```

### Family Status Heatmap

**Question** — What is each Semáforo Héroes family’s current status by dimension, and how can we focus on a specific dimension (e.g., Health & Environment)?  
**Recommended visualization** — heatmap (families × dimensions) with optional slicer by dimension.

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT
  mfd.family_id,
  fam.family_name,
  mfd.dimension_id,
  mfd.dimension_name,
  mfd.dimension_score,
  mfd.pct_red,
  mfd.pct_yellow,
  mfd.pct_green,
  mfd.indicators_count,
  mfd.family_id_public
FROM mart_marts.mart_family_dimension_current mfd
JOIN survey_filter sf USING (survey_definition_id)
LEFT JOIN mart_marts.dim_family fam USING (family_id)
-- Optional dimension focus:
-- WHERE mfd.dimension_name IN ('Health', 'Environment')
ORDER BY mfd.family_id, mfd.dimension_name;
```

---

### Dimension Performance Summary

**Question** — On average, which dimensions perform best, and how many families land in green/yellow/red for each dimension?  
**Recommended visualization** — (1) sorted bar chart of average scores, (2) stacked bar chart of family distribution by dominant color.

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
),
scored AS (
  SELECT
    mfd.dimension_id,
    mfd.dimension_name,
    mfd.family_id,
    mfd.dimension_score,
    CASE
      WHEN mfd.pct_green >= GREATEST(mfd.pct_yellow, mfd.pct_red) THEN 'Green'
      WHEN mfd.pct_yellow >= GREATEST(mfd.pct_green, mfd.pct_red) THEN 'Yellow'
      ELSE 'Red'
    END AS dominant_color
  FROM mart_marts.mart_family_dimension_current mfd
  JOIN survey_filter sf USING (survey_definition_id)
)
SELECT
  dimension_id,
  dimension_name,
  AVG(dimension_score) AS avg_dimension_score,
  COUNT(*) FILTER (WHERE dominant_color = 'Green') * 1.0 / COUNT(*) AS share_green,
  COUNT(*) FILTER (WHERE dominant_color = 'Yellow') * 1.0 / COUNT(*) AS share_yellow,
  COUNT(*) FILTER (WHERE dominant_color = 'Red') * 1.0 / COUNT(*) AS share_red
FROM scored
GROUP BY 1, 2
ORDER BY avg_dimension_score DESC;
```

---

### Heroes Families With a Snapshot

**Question** — How many Semáforo Héroes families currently have an active snapshot?  
**Recommended visualization** — KPI card; reference during the demo to show cohort size.

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT COUNT(DISTINCT sc.family_id) AS active_families_current
FROM mart_marts.mart_snapshot_current sc
JOIN survey_filter sf USING (survey_definition_id);
```

---

### Recent Heroes Activity (Last 8 Weeks)

**Question** — How many Semáforo Héroes families submitted a snapshot in the last eight weeks?  
**Recommended visualization** — eight-week trend line or area chart.

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT COUNT(DISTINCT sc.family_id) AS active_families_last_8_weeks
FROM mart_marts.mart_snapshot_current sc
JOIN survey_filter sf USING (survey_definition_id)
WHERE sc.snapshot_ts >= CURRENT_DATE - INTERVAL '56 day';
```

---

### Dimension Evolution: Baseline vs. Latest Snapshot

**Question** — How have average dimension scores evolved from baseline to the most recent snapshot?  
**Recommended visualization** — paired line charts (baseline vs. latest) or a clustered line chart per dimension.

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
),
-- Map each snapshot to its dimension indicators
indicator_map AS (
  SELECT
    ss.survey_definition_id,
    ss.code_name,
    ss.survey_dimension_id AS dimension_id,
    ss.dimension AS dimension_name
  FROM data_collect.survey_stoplight ss
),
-- Helper to convert stoplight values to scores: 1=Red (0.0), 2=Yellow (0.5), 3=Green (1.0)
indicator_scores AS (
  SELECT
    sn.snapshot_id,
    sn.family_id,
    sn.survey_definition_id,
    sn.snapshot_number,
    sn.snapshot_stage,
    im.dimension_id,
    im.dimension_name,
    CASE sl.value
      WHEN 1 THEN 0.0
      WHEN 2 THEN 0.5
      WHEN 3 THEN 1.0
      ELSE NULL
    END AS indicator_score
  FROM (
    SELECT
      fs.snapshot_id,
      fs.family_id,
      fs.survey_definition_id,
      fs.snapshot_number,
      CASE
        WHEN fs.snapshot_number = 1 THEN 'Baseline'
        WHEN fs.is_last_with_stoplight = TRUE THEN 'Latest'
      END AS snapshot_stage
    FROM mart_marts.fact_snapshot fs
    JOIN survey_filter sf USING (survey_definition_id)
    WHERE fs.snapshot_number = 1 OR fs.is_last_with_stoplight = TRUE
  ) sn
  JOIN data_collect.snapshot_stoplight sl
    ON sl.snapshot_id = sn.snapshot_id
  JOIN indicator_map im
    ON im.survey_definition_id = sn.survey_definition_id
   AND im.code_name = sl.code_name
  WHERE sn.snapshot_stage IS NOT NULL
    AND sl.value IN (1, 2, 3)
),
dimension_stage AS (
  SELECT
    dimension_id,
    dimension_name,
    snapshot_stage,
    AVG(indicator_score) AS avg_dimension_score
  FROM indicator_scores
  GROUP BY 1, 2, 3
)
SELECT *
FROM dimension_stage
ORDER BY dimension_name, snapshot_stage;
```

---

### Highest-Need Hotspots With Location

**Question** — Where are the Semáforo Héroes families that need the most urgent support located?  
**Recommended visualization** — map heatmap or bubble map filtered by a score threshold.

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT
  mfd.family_id,
  fam.family_name,
  fam.latitude,
  fam.longitude,
  mfd.dimension_name,
  mfd.dimension_score,
  mfd.pct_red,
  mfd.family_id_public
FROM mart_marts.mart_family_dimension_current mfd
JOIN survey_filter sf USING (survey_definition_id)
LEFT JOIN mart_marts.dim_family fam USING (family_id)
WHERE mfd.dimension_score <= 0.4 -- adjust threshold to highlight urgent cases
  AND fam.latitude IS NOT NULL
  AND fam.longitude IS NOT NULL
ORDER BY mfd.dimension_score ASC;
```

Use these targeted views to build demos that move from high-level coverage to action-ready insights. Let me know if you want companion notebook cells or dashboard mock-ups. 
