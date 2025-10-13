# Semantic Layer - Poverty Stoplight

This directory contains the semantic model and metrics definitions for the Poverty Stoplight data platform. The semantic layer provides a consistent, business-friendly interface for querying snapshot and family engagement data.

## Overview

The semantic layer is built using **dbt MetricFlow**, which allows you to define reusable metrics that can be queried consistently across different tools and contexts.

**Key components:**
- `snapshot.yml` - Semantic model defining entities, dimensions, and measures
- `metrics.yml` - Business metrics built on the semantic model

## Available Metrics

### 1. Active Families (Current)
**Metric name:** `active_families_current`
**Type:** Simple count
**Description:** Number of currently active families based on their most recent snapshot

**Use case:** Track the current size of your active family population

---

### 2. Baseline Families
**Metric name:** `baseline_families`
**Type:** Simple count
**Description:** Number of families with baseline surveys (initial assessment)

**Use case:** Understand program reach and total enrollment

---

### 3. Follow-up Families
**Metric name:** `followup_families`
**Type:** Simple count
**Description:** Number of families with at least one follow-up survey

**Use case:** Track which families have been re-engaged after the baseline

---

### 4. Follow-up Coverage (Any) ⭐
**Metric name:** `followup_coverage_any`
**Type:** Ratio (percentage)
**Description:** Percentage of families with at least one follow-up survey of any type

**Calculation:** (Families with follow-up) / (Families with baseline) × 100

**Use case:** **PRIMARY KPI** - Measures program engagement and retention

---

### 5. Follow-up Coverage (Stoplight) ⭐
**Metric name:** `followup_coverage_stoplight`
**Type:** Ratio (percentage)
**Description:** Percentage of families with at least one follow-up survey containing stoplight data

**Calculation:** (Families with stoplight follow-up) / (Families with baseline) × 100

**Use case:** **PRIMARY KPI** - Measures data quality and completeness of follow-up assessments

---

## Querying Metrics

### Using MetricFlow CLI

MetricFlow provides a command-line interface for querying metrics directly:

```bash
# Navigate to dbt directory
cd dbt

# List all available metrics
dbt sl list metrics

# Query a simple metric
dbt sl query --metrics active_families_current

# Query with time dimension grouping
dbt sl query --metrics baseline_families --group-by metric_time__year

# Query multiple metrics together
dbt sl query --metrics followup_coverage_any,followup_coverage_stoplight

# Query with dimension filters
dbt sl query \
  --metrics active_families_current \
  --group-by snapshot__snapshot_number \
  --where "snapshot__snapshot_ts >= '2024-01-01'"

# Query with organization breakdown
dbt sl query \
  --metrics followup_coverage_any \
  --group-by organization__organization_name \
  --order-by -followup_coverage_any
```

### Using dbt Exposures (for BI tools)

If you're using LightDash or another BI tool, you can create dbt exposures that reference these metrics:

```yaml
# models/exposures.yml
exposures:
  - name: family_engagement_dashboard
    type: dashboard
    maturity: high
    owner:
      name: Data Team
      email: data@example.com

    depends_on:
      - ref('fact_snapshot')

    metrics:
      - active_families_current
      - followup_coverage_any
      - followup_coverage_stoplight
```

---

## Semantic Model Structure

### Entities

The semantic model defines these entities for joining and relationships:

- **snapshot** (primary) - Individual survey snapshots
- **family** (foreign) - Family being assessed
- **organization** (foreign) - Organization conducting survey
- **application** (foreign) - Application/hub context
- **survey_definition** (foreign) - Survey template used

### Dimensions

Dimensions available for filtering and grouping:

| Dimension | Type | Description |
|-----------|------|-------------|
| `snapshot_ts` | time | Timestamp when snapshot was taken |
| `is_baseline` | categorical | Flag for baseline surveys (snapshot_number = 1) |
| `is_last_any` | categorical | Flag for most recent snapshot (any type) |
| `is_last_with_stoplight` | categorical | Flag for most recent snapshot with stoplight |
| `anonymous` | categorical | Privacy flag for anonymous surveys |
| `snapshot_number` | categorical | Survey round number |

### Measures

Base measures used to build metrics:

| Measure | Aggregation | Description |
|---------|-------------|-------------|
| `snapshots` | count | Count of all snapshots |
| `families_distinct` | count_distinct | Count of distinct families |
| `orgs_distinct` | count_distinct | Count of distinct organizations |
| `median_days_between` | median | Median days between successive snapshots |

---

## Example Queries

### 1. Track follow-up coverage over time
```bash
dbt sl query \
  --metrics followup_coverage_any,followup_coverage_stoplight \
  --group-by metric_time__year \
  --order-by metric_time__year
```

### 2. Compare organizations by engagement
```bash
dbt sl query \
  --metrics baseline_families,followup_families,followup_coverage_any \
  --group-by organization__organization_name \
  --order-by -followup_coverage_any
```

### 3. Recent activity (last 90 days)
```bash
dbt sl query \
  --metrics active_families_current \
  --where "snapshot__snapshot_ts >= CURRENT_DATE - interval '90 days'"
```

### 4. Baseline vs Follow-up comparison
```bash
dbt sl query \
  --metrics families_distinct \
  --group-by snapshot__is_baseline
```

---

## Troubleshooting

### Error: "Unknown metric"
Make sure you've run `dbt parse` after creating or modifying metrics:
```bash
dbt parse
```

### Error: "Could not find relation"
Ensure all upstream models are built:
```bash
dbt build --select fact_snapshot+
```

### Metric returns NULL or 0
- Check that fact_snapshot has data: `dbt run --select fact_snapshot`
- Verify filters in your query match actual data values
- Check `is_last_any` and `is_baseline` flags are populated correctly

### MetricFlow not installed
Install the package:
```bash
uv pip install dbt-metricflow
```

---

## Data Quality Notes

### Known Issues

1. **Multiple baselines per family**: Some families have multiple baseline snapshots (snapshot_number = 1). This is a known data quality issue in the source system. A warning test alerts when this occurs.

2. **Low follow-up rates**: Follow-up coverage is typically very low (0-9% range). This is expected behavior reflecting real-world program engagement challenges.

### Test Coverage

The semantic layer includes these automated tests:
- ✅ Snapshot timestamps are plausible (between 2000 and now)
- ✅ Unique combination of (family_id, snapshot_number, survey_definition_id)
- ✅ Single baseline per family (warning only)
- ✅ All foreign keys have valid references

Run tests with:
```bash
dbt test --select fact_snapshot
```

---

## Further Reading

- [dbt MetricFlow Documentation](https://docs.getdbt.com/docs/build/metricflow)
- [Semantic Layer Best Practices](https://docs.getdbt.com/docs/build/about-metricflow)
- Project Schema Documentation: `docs/SCHEMA.md`

---

## Support

For questions about metrics definitions or issues with the semantic layer:
1. Check existing dbt tests: `dbt test`
2. Validate models are up to date: `dbt build`
3. Review source data quality in `fact_snapshot`
