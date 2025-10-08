# Mart Reporting Toolkit

## Broad Questions (Whole Dataset)

### Active Families (Current)

**Business question** — How many families across the network currently have a valid snapshot on record?

```sql
SELECT COUNT(DISTINCT family_id) AS active_families_current
FROM mart_marts.mart_snapshot_current;
```

**Recommended visualization** — Single KPI card (optionally trend over time).

### Active Families by Organization/Application

**Business question** — Which organization and application combinations contribute the highest number of active families?

```sql
SELECT
  organization_id,
  application_id,
  COUNT(DISTINCT family_id) AS active_families_current
FROM mart_marts.mart_snapshot_current
GROUP BY 1, 2
ORDER BY active_families_current DESC;
```

**Recommended visualization** — Horizontal bar chart sorted descending to spotlight leaders.

### Baseline Families

**Business question** — How many unique families have completed a baseline snapshot overall?

```sql
SELECT COUNT(DISTINCT family_id) AS baseline_families
FROM mart_marts.mart_snapshot_baseline;
```

**Recommended visualization** — KPI card (pair with follow-up metrics for context).

### Baseline Families by Organization/Application

**Business question** — Where are baseline engagements concentrated across organizations and applications?

```sql
SELECT
  organization_id,
  application_id,
  COUNT(DISTINCT family_id) AS baseline_families
FROM mart_marts.mart_snapshot_baseline
GROUP BY 1, 2
ORDER BY baseline_families DESC;
```

**Recommended visualization** — Stacked bar chart per organization with application segments.

### Follow-up Families

**Business question** — How many families progressed beyond their first snapshot anywhere in the platform?

```sql
SELECT COUNT(DISTINCT family_id) AS followup_families
FROM mart_marts.fact_snapshot
WHERE snapshot_number > 1;
```

**Recommended visualization** — KPI card or progress gauge alongside baseline totals.

### Follow-up Families by Organization/Application

**Business question** — Which organization/application teams are delivering the most follow-up activity?

```sql
SELECT
  organization_id,
  application_id,
  COUNT(DISTINCT family_id) AS followup_families
FROM mart_marts.fact_snapshot
WHERE snapshot_number > 1
GROUP BY 1, 2
ORDER BY followup_families DESC;
```

**Recommended visualization** — Clustered column chart to compare organizations.

### Follow-up Coverage (Any)

**Business question** — What share of baseline families has at least one follow-up snapshot?

```sql
WITH baseline AS (
  SELECT DISTINCT family_id FROM mart_marts.mart_snapshot_baseline
),
followup AS (
  SELECT DISTINCT family_id FROM mart_marts.fact_snapshot
  WHERE snapshot_number > 1
)
SELECT
  COUNT(DISTINCT f.family_id) * 1.0
  / NULLIF(COUNT(DISTINCT b.family_id), 0) AS followup_coverage
FROM baseline b
LEFT JOIN followup f USING (family_id);
```

**Recommended visualization** — Gauge or donut chart indicating percentage.

### Follow-up Coverage by Organization

**Business question** — Which organizations retain families through follow-ups most effectively?

```sql
WITH baseline AS (
  SELECT DISTINCT organization_id, family_id
  FROM mart_marts.mart_snapshot_baseline
),
followup AS (
  SELECT DISTINCT organization_id, family_id
  FROM mart_marts.fact_snapshot
  WHERE snapshot_number > 1
)
SELECT
  b.organization_id,
  COUNT(DISTINCT f.family_id) * 1.0
  / NULLIF(COUNT(DISTINCT b.family_id), 0) AS followup_coverage
FROM baseline b
LEFT JOIN followup f
  ON f.organization_id = b.organization_id
 AND f.family_id = b.family_id
GROUP BY 1
ORDER BY followup_coverage DESC;
```

**Recommended visualization** — Bullet chart or sorted bar chart to benchmark performance.

### Anonymous Share (Current)

**Business question** — What proportion of current snapshots are recorded anonymously across the platform?

```sql
SELECT
  SUM(CASE WHEN anonymous THEN 1 ELSE 0 END) * 1.0
  / NULLIF(COUNT(*), 0) AS share_anonymous_current
FROM mart_marts.mart_snapshot_current;
```

**Recommended visualization** — Donut chart comparing anonymous vs. identified records.

### Median Days Between Snapshots

**Business question** — What is the typical cadence between successive snapshots for engaged families?

```sql
SELECT
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_since_prev) AS median_days_between
FROM mart_marts.fact_snapshot
WHERE days_since_prev IS NOT NULL;
```

**Recommended visualization** — KPI card, optionally paired with historical sparkline.

### Median Days by Organization

**Business question** — Which organizations move families through follow-ups fastest?

```sql
SELECT
  organization_id,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_since_prev) AS median_days_between
FROM mart_marts.fact_snapshot
WHERE days_since_prev IS NOT NULL
GROUP BY 1
ORDER BY median_days_between;
```

**Recommended visualization** — Sorted bar or dot plot highlighting standouts.

### Quick-Win Dimension Insights (Expanded)

#### Family Status by Dimension (Detail View)

**Business question** — What is each family’s current status per dimension, including color mix and score?

```sql
SELECT
  family_id,
  organization_id,
  application_id,
  survey_definition_id,
  dimension_id,
  dimension_name,
  pct_red,
  pct_yellow,
  pct_green,
  dimension_score,
  indicators_count,
  red_count,
  yellow_count,
  green_count,
  is_anonymous,
  family_id_public
FROM mart_marts.mart_family_dimension_current
ORDER BY family_id, dimension_name;
```

**Recommended visualization** — Heat map (families × dimensions) or searchable table with conditional formatting.

#### Dimension Summary Metrics (Whole Dataset)

**Business question** — On average, which dimensions perform best and which are most critical across all families?

```sql
SELECT
  dimension_id,
  dimension_name,
  AVG(dimension_score) AS avg_dimension_score,
  AVG(pct_red) AS avg_pct_red,
  AVG(pct_yellow) AS avg_pct_yellow,
  AVG(pct_green) AS avg_pct_green,
  SUM(indicators_count) AS total_indicators_tracked,
  COUNT(DISTINCT family_id) AS families_measured
FROM mart_marts.mart_family_dimension_current
GROUP BY 1, 2
ORDER BY avg_dimension_score;
```

**Recommended visualization** — Sorted bar chart of average scores with stacked color distribution.

#### Families with Highest Red Concentration (Watchlist)

**Business question** — Which families face the greatest concentration of red indicators today?

```sql
SELECT
  family_id,
  organization_id,
  application_id,
  dimension_name,
  red_count,
  indicators_count,
  pct_red,
  dimension_score
FROM mart_marts.mart_family_dimension_current
WHERE red_count > 0
ORDER BY pct_red DESC, dimension_score ASC
LIMIT 50;
```

**Recommended visualization** — Table or bubble chart to support targeted interventions.

### Recent Active Families (Recency Filter)

**Business question** — How many active families have submitted a snapshot in the last eight weeks?

```sql
SELECT COUNT(DISTINCT family_id) AS active_families_current_8w
FROM mart_marts.mart_snapshot_current
WHERE snapshot_ts >= CURRENT_DATE - INTERVAL '56 day';
```

**Recommended visualization** — Rolling eight-week trend line or area chart.

---

## Demo: Survey Heroes FP (Semáforo Héroes)

*Filter template used in each query*

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
```

Each query below reuses this CTE; adjust to incorporate it directly.

### Active Families (Current)

**Business question** — How many Semáforo Héroes families currently have a valid snapshot?

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

**Recommended visualization** — Single KPI card for the demo cohort.

### Baseline Families

**Business question** — How many Semáforo Héroes families completed their baseline snapshot?

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT COUNT(DISTINCT sb.family_id) AS baseline_families
FROM mart_marts.mart_snapshot_baseline sb
JOIN survey_filter sf USING (survey_definition_id);
```

**Recommended visualization** — KPI card paired with follow-up metric.

### Follow-up Families

**Business question** — How many Semáforo Héroes families advanced beyond their first snapshot?

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT COUNT(DISTINCT fs.family_id) AS followup_families
FROM mart_marts.fact_snapshot fs
JOIN survey_filter sf USING (survey_definition_id)
WHERE fs.snapshot_number > 1;
```

**Recommended visualization** — KPI card; narrate progress vs. baseline.

### Follow-up Coverage (Any)

**Business question** — What share of Semáforo Héroes baseline families returned for a follow-up snapshot?

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
),
baseline AS (
  SELECT DISTINCT family_id
  FROM mart_marts.mart_snapshot_baseline
  JOIN survey_filter USING (survey_definition_id)
),
followup AS (
  SELECT DISTINCT family_id
  FROM mart_marts.fact_snapshot
  JOIN survey_filter USING (survey_definition_id)
  WHERE snapshot_number > 1
)
SELECT
  COUNT(DISTINCT f.family_id) * 1.0
  / NULLIF(COUNT(DISTINCT b.family_id), 0) AS followup_coverage
FROM baseline b
LEFT JOIN followup f USING (family_id);
```

**Recommended visualization** — Gauge focused on follow-up conversion.

### Anonymous Share (Current)

**Business question** — What proportion of current Semáforo Héroes snapshots are marked anonymous?

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT
  SUM(CASE WHEN sc.anonymous THEN 1 ELSE 0 END) * 1.0
  / NULLIF(COUNT(*), 0) AS share_anonymous_current
FROM mart_marts.mart_snapshot_current sc
JOIN survey_filter sf USING (survey_definition_id);
```

**Recommended visualization** — Donut chart to discuss privacy mix.

### Median Days Between Snapshots

**Business question** — What is the typical cadence between Semáforo Héroes snapshots?

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY fs.days_since_prev) AS median_days_between
FROM mart_marts.fact_snapshot fs
JOIN survey_filter sf USING (survey_definition_id)
WHERE fs.days_since_prev IS NOT NULL;
```

**Recommended visualization** — KPI card; compare against broad benchmark during the demo.

### Quick-Win Dimension Insights (Semáforo Héroes)

#### Family Status by Dimension (Detail)

**Business question** — What is the current dimension status for each Semáforo Héroes family?

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT
  mfd.family_id,
  mfd.dimension_id,
  mfd.dimension_name,
  mfd.pct_red,
  mfd.pct_yellow,
  mfd.pct_green,
  mfd.dimension_score,
  mfd.indicators_count,
  mfd.red_count,
  mfd.yellow_count,
  mfd.green_count,
  mfd.family_id_public
FROM mart_marts.mart_family_dimension_current mfd
JOIN survey_filter sf USING (survey_definition_id)
ORDER BY mfd.family_id, mfd.dimension_name;
```

**Recommended visualization** — Heat map or filterable table for live walkthroughs.

#### Dimension Summary Metrics (Semáforo Héroes)

**Business question** — Which dimensions are the strongest and weakest within Semáforo Héroes?

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT
  mfd.dimension_id,
  mfd.dimension_name,
  AVG(mfd.dimension_score) AS avg_dimension_score,
  AVG(mfd.pct_red) AS avg_pct_red,
  AVG(mfd.pct_yellow) AS avg_pct_yellow,
  AVG(mfd.pct_green) AS avg_pct_green,
  SUM(mfd.indicators_count) AS total_indicators_tracked,
  COUNT(DISTINCT mfd.family_id) AS families_measured
FROM mart_marts.mart_family_dimension_current mfd
JOIN survey_filter sf USING (survey_definition_id)
GROUP BY 1, 2
ORDER BY avg_dimension_score;
```

**Recommended visualization** — Sorted bar chart highlighting critical dimensions, ideal for demo storytelling.

#### Families with Highest Red Concentration (Semáforo Héroes Watchlist)

**Business question** — Which Semáforo Héroes families need the most urgent attention by dimension?

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT
  mfd.family_id,
  mfd.dimension_name,
  mfd.red_count,
  mfd.indicators_count,
  mfd.pct_red,
  mfd.dimension_score,
  mfd.family_id_public
FROM mart_marts.mart_family_dimension_current mfd
JOIN survey_filter sf USING (survey_definition_id)
WHERE mfd.red_count > 0
ORDER BY mfd.pct_red DESC, mfd.dimension_score ASC
LIMIT 25;
```

**Recommended visualization** — Table with conditional formatting to drive intervention discussion.

### Recent Active Families (Semáforo Héroes)

**Business question** — How many Semáforo Héroes families were active in the last eight weeks?

```sql
WITH survey_filter AS (
  SELECT survey_definition_id
  FROM mart_marts.dim_survey_definition
  WHERE survey_title = 'Semáforo Héroes'
)
SELECT COUNT(DISTINCT sc.family_id) AS active_families_current_8w
FROM mart_marts.mart_snapshot_current sc
JOIN survey_filter sf USING (survey_definition_id)
WHERE sc.snapshot_ts >= CURRENT_DATE - INTERVAL '56 day';
```

**Recommended visualization** — Eight-week trend line to demonstrate recency during the demo.

Let me know if you’d like to layer in comparisons (demo cohort vs. overall) or turn any of these blocks into ready-to-share slide copy.

