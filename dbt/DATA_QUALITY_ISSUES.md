# Data Quality Issues

This document tracks known data quality issues in the source database that affect dbt tests and analytics.

---

## Stoplight Indicator Values

**Table:** `data_collect.snapshot_stoplight`
**Column:** `value` (mapped to `indicator_status_value` in staging)

The stoplight scoring system expects values of 1 (Red), 2 (Yellow), or 3 (Green). However, the source data contains unexpected values that appear to be data entry errors or system anomalies:

| Value | Count | Notes |
|-------|-------|-------|
| 4 | 3 | Invalid |
| 6 | 2 | Invalid |
| 10 | 1 | Invalid |
| 23 | 1 | Invalid |
| 31 | 1 | Invalid |
| 9 | 32,363 | Legacy/skipped indicator code |

These records represent a small fraction of the ~39 million total stoplight responses. The `accepted_values` test in `stg_snapshot_stoplight` is configured as a warning rather than a failure to accommodate this.

**Recommendation:** Investigate the source application to understand how these values were recorded and whether they should be corrected or filtered.

---

## Orphaned Family Members

**Table:** `ps_families.family_members`
**Column:** `family_id`

9 family member records have null `family_id`, making them orphaned (not linked to any family):

| IDs | Count | Notes |
|-----|-------|-------|
| 1427898–1427906 | 9 | Consecutive IDs, all created 2023-11-01 by `admin-async` |

These appear to be remnants of a failed batch import. All have Spanish names and null `snapshot_id`.

**Recommendation:** Filter these records in staging models or investigate source system for cleanup.

---

## Economic Records Missing Answer Type

**Table:** `data_collect.snapshot_economic`
**Column:** `answer_type`

914 records have null `answer_type` out of 16 million total (0.006%):

| Updated By | Count | Date Range |
|------------|-------|------------|
| Carol Houssock | 493 | Jan–Mar 2019 |
| Jessica 2 | 300 | Feb–Mar 2019 |
| Paola Quezada | 110 | Jan 2019 |
| Andy C | 11 | Feb 2019 |

All records also have null `created_by` and `created_date`. Appears to be legacy data from an earlier system version before `answer_type` was required.

**Recommendation:** Default to `'string'` in staging models or exclude these records.

---

## Orphaned Stoplight Priorities and Achievements

**Tables:** `data_collect.snapshot_stoplight_priority`, `data_collect.snapshot_stoplight_achievement`
**Column:** `snapshot_stoplight_id`

Records referencing non-existent `snapshot_stoplight.id` values:

| Table | Total Rows | Orphaned | % |
|-------|------------|----------|---|
| `snapshot_stoplight_priority` | 1,453,656 | 10,674 | 0.73% |
| `snapshot_stoplight_achievement` | 408,280 | 2,372 | 0.58% |

All orphaned records created **Nov 26 – Dec 10, 2025** by hundreds of different users. This is a **data sync lag** issue — child tables receive new records before parent `snapshot_stoplight` records are synced to the warehouse.

**Recommendation:** Use LEFT JOIN in staging models and filter nulls, or wait for sync to complete before running analytics.

---

## Snapshot Number vs Date Ordering Inconsistency

**Table:** `data_collect.snapshot`
**Columns:** `snapshot_number`, `snapshot_date`, `created_at`

The source `snapshot_number` does not always match chronological order by `snapshot_date`:

| Order By | Mismatches | Affected Families | % of Total |
|----------|------------|-------------------|------------|
| `snapshot_date` | 24,302 | 10,328 | 2.4% of 1,021,139 snapshots |
| `created_at` | 275 | 133 | 0.03% |

Most common mismatch patterns (by `snapshot_date`):

| Source # | Chronological # | Count |
|----------|-----------------|-------|
| 1 → 2 | 7,603 | "Baseline" dated after 2nd survey |
| 2 → 1 | 7,102 | "Follow-up" dated before baseline |

These two patterns account for 60% of all mismatches.

**Impact:** Affects longitudinal analysis — baseline/follow-up classification may be incorrect for ~10K families depending on which date field is used.

**Current handling:** `int_snapshots` recomputes `snapshot_number` using `ORDER BY snapshot_date, created_at, id`. This changes the sequence for 24K records.

**Note:** When ordering by `created_at`, the source `snapshot_number` matches 99.97% of records (only 275 mismatches).

**Open question:** Unknown whether source `snapshot_number` is assigned by `created_at` order, manual entry, or another mechanism.

---

## Duplicate code_name in Survey Definitions

**Table:** `data_collect.survey_stoplight`
**Columns:** `survey_definition_id`, `code_name`

One duplicate found: Survey 80 uses `code_name = 'socialCapital'` for two different indicators:

| ID | short_name | order_number |
|----|------------|--------------|
| 3677 | Social Capital | 32 |
| 3684 | Group Activities | 39 |

**Impact:** None. Survey 80 has **zero snapshots** — it was never deployed. The duplicate exists in the definition but causes no response ambiguity.

**Note:** `data_model/DATA_QUALITY.md` documents 9 duplicate rows (likely from Demo database). Warehouse has only this one case.
