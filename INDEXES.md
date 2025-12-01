# Index Documentation

This document tracks manually created indexes on the **Poverty-Stoplight-Warehouse** Neon project (`sparkling-wave-17609138`).

> **Note:** These indexes were created manually for performance testing. Once validated, they should be added to the dbt model configuration.

## Current Indexes on `analytics_marts.mart_indicators`

Last updated: 2025-12-01

| Index Name | Column | Source | Purpose |
|------------|--------|--------|---------|
| `173b2ed23c56bb787a48b91d45377b32` | `application_id` | dbt config | RLS filtering |
| `23b747ebe6ec7f0376ce5f624887fb93` | `family_id` | dbt config | Row-level queries |
| `593badef5080f4004cf852abe8224dad` | `indicator_name` | dbt config | GROUP BY |
| `942712c91b75e9afcb0719e8500ffe05` | `latest_followup_value` | dbt config | CASE aggregations |
| `cfc61ae391f5a202c75135d8c5d24895` | `has_followup_data` | dbt config | WHERE filter |
| `dee911cf60897333abc67833ca992321` | `application_name` | dbt config | Dropdown filter |
| `idx_mart_indicators_baseline_label` | `baseline_label` | Manual | GROUP BY |
| `idx_mart_indicators_dimension_name` | `dimension_name` | Manual | WHERE + GROUP BY |
| `idx_mart_indicators_first_followup_label` | `first_followup_label` | Manual | GROUP BY |
| `idx_mart_indicators_first_followup_value` | `first_followup_value` | Manual | CASE aggregations |
| `idx_mart_indicators_latest_followup_label` | `latest_followup_label` | Manual | GROUP BY |
| `idx_mart_indicators_project_name` | `project_name` | Manual | Dropdown filter |
| `idx_mart_indicators_survey_title` | `survey_title` | Manual | Dropdown filter |

**Total: 13 indexes**

---

## Query Performance Analysis (EXPLAIN ANALYZE)

Tested on 2025-12-01 against ~20M rows (16GB table)

### Query 1: Simple GROUP BY baseline_label
```sql
SELECT baseline_label, COUNT(*)
FROM analytics_marts.mart_indicators
GROUP BY baseline_label
```
| Metric | Value |
|--------|-------|
| **Execution Time** | **1.23 seconds** |
| Scan Type | ✅ Parallel Index Only Scan |
| Index Used | `idx_mart_indicators_baseline_label` |
| Workers | 2 |

**Assessment:** Index is working perfectly. "Index Only Scan" means PostgreSQL doesn't even need to touch the table data.

---

### Query 2: Indicator comparison (baseline vs follow-up)
```sql
SELECT indicator_name,
       SUM(CASE WHEN baseline_value IN (1,2) THEN 1 ELSE 0 END),
       SUM(CASE WHEN first_followup_value IN (1,2) THEN 1 ELSE 0 END)
FROM analytics_marts.mart_indicators
GROUP BY indicator_name
```
| Metric | Value |
|--------|-------|
| **Execution Time** | **5.9 seconds** |
| Scan Type | ⚠️ Parallel Seq Scan |
| Index Used | None |
| Workers | 2 |

**Assessment:** Sequential scan is expected here. The query needs to read `baseline_value` and `first_followup_value` for every row to compute the CASE expressions. No index can help because we're aggregating across the entire table.

---

### Query 3: Filtered by dimension + has_followup_data
```sql
SELECT indicator_name, AVG(CASE WHEN baseline_value = 3 THEN 1.0 ELSE 0.0 END)
FROM analytics_marts.mart_indicators
WHERE dimension_name = 'Agricultural Development' AND has_followup_data = true
GROUP BY indicator_name
```
| Metric | Value |
|--------|-------|
| **Execution Time** | **70 milliseconds** |
| Scan Type | ✅ Bitmap Index Scan |
| Index Used | `idx_mart_indicators_dimension_name` |
| Rows Scanned | 20,513 (filtered to 481) |

**Assessment:** Excellent performance! The `dimension_name` index dramatically reduces the scan from 20M rows to ~20K. This is **85x faster** than a full table scan would be.

---

### Query 4: GROUP BY dimension with has_followup_data filter
```sql
SELECT dimension_name, AVG(CASE WHEN baseline_value = 3 THEN 1.0 ELSE 0.0 END)
FROM analytics_marts.mart_indicators
WHERE has_followup_data = true
GROUP BY dimension_name
```
| Metric | Value |
|--------|-------|
| **Execution Time** | **5.0 seconds** |
| Scan Type | ⚠️ Parallel Seq Scan |
| Index Used | None |
| Rows Filtered | 3.4M removed, 9.7M kept (~48% selectivity) |

**Assessment:** PostgreSQL chooses seq scan because `has_followup_data = true` matches ~48% of rows. When filtering keeps nearly half the data, sequential scan is often faster than index lookup + heap fetches.

---

### Query 5: GROUP BY baseline_label with has_followup_data filter
```sql
SELECT baseline_label, COUNT(*)
FROM analytics_marts.mart_indicators
WHERE has_followup_data = true
GROUP BY baseline_label
```
| Metric | Value |
|--------|-------|
| **Execution Time** | **4.7 seconds** |
| Scan Type | ⚠️ Parallel Seq Scan |
| Index Used | None |

**Assessment:** Same issue as Query 4. The `has_followup_data` filter has low selectivity.

---

### Query 6: GROUP BY first_followup_label with has_followup_data filter
```sql
SELECT first_followup_label, COUNT(*)
FROM analytics_marts.mart_indicators
WHERE has_followup_data = true
GROUP BY first_followup_label
```
| Metric | Value |
|--------|-------|
| **Execution Time** | **4.5 seconds** |
| Scan Type | ⚠️ Parallel Seq Scan |
| Index Used | None |

**Assessment:** Same pattern. Sequential scan chosen due to low selectivity.

---

## Performance Summary

| Query Type | Time | Index Benefit |
|------------|------|---------------|
| Simple GROUP BY (no filter) | 1.2s | ✅ High (Index Only Scan) |
| Full table aggregation | 5-6s | ❌ None possible |
| Highly selective filter (dimension) | **70ms** | ✅ Very High (85x faster) |
| Low selectivity filter (has_followup) | 4-5s | ❌ Minimal benefit |

---

## Recommendations

### What's Working Well
1. **`dimension_name` index** - Dramatic improvement for dimension-specific queries
2. **`baseline_label` index** - Enables Index Only Scan for simple aggregations
3. **Dropdown filter indexes** - Ready for selective filtering by app/org/survey

### Potential Optimizations

#### Option A: Partial Index for Follow-up Cohort
Since ~48% of data has `has_followup_data = true`, a partial index might help:

```sql
CREATE INDEX idx_mart_indicators_followup_baseline_label
ON analytics_marts.mart_indicators (baseline_label)
WHERE has_followup_data = true;
```

This would create a smaller index covering only the follow-up cohort, potentially enabling Index Only Scans for queries 5 and 6.

#### Option B: Composite Index
```sql
CREATE INDEX idx_mart_indicators_followup_dimension
ON analytics_marts.mart_indicators (has_followup_data, dimension_name);
```

Would help queries that filter by both columns together.

#### Option C: Accept Current Performance
5 seconds for full-cohort queries on a 16GB table with parallel workers is reasonable. The most impactful queries (dimension-specific analysis) already run in <100ms.

---

## Maintenance Notes

### After dbt run
When `dbt run` rebuilds `mart_indicators`, it will:
- Drop and recreate the table (losing manual indexes)
- Create only indexes defined in the model's `config()` block

**Action Required:** Once performance is validated, update `mart_indicators.sql` config to include:
```sql
indexes=[
    -- existing indexes...
    {'columns': ['dimension_name']},
    {'columns': ['survey_title']},
    {'columns': ['project_name']},
    {'columns': ['first_followup_value']},
    {'columns': ['baseline_label']},
    {'columns': ['first_followup_label']},
    {'columns': ['latest_followup_label']}
]
```

### Removed Duplicate Indexes (2025-12-01)
The following duplicate indexes were dropped:
- `6c579eb45086ea601b5e7755caedaf6b` (duplicate `organization_name`)
- `99fae4b1e73509767e8f4d63fd47e03a` (duplicate `baseline_value`)
- `idx_mart_indicators_org_name` (duplicate)
- `idx_mart_indicators_baseline_value` (duplicate)
