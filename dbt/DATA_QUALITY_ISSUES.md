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

## Duplicate Priority Records

**Table:** `data_collect.snapshot_stoplight_priority`
**Column:** `snapshot_stoplight_id`

22 stoplight snapshots have exactly 2 priority records each (exact duplicates):

| Metric | Value |
|--------|-------|
| Total priority records | 1,453,656 |
| Unique snapshot_stoplight_ids | 1,453,634 |
| Duplicates | 22 |
| Percentage | 0.0015% |

Example duplicate (snapshot_stoplight_id = 18151652):

| id | reason | action | created_at | created_by |
|----|--------|--------|------------|------------|
| 1022229 | They don't have enough income | They said that they will try to fix it in the future | 1719675371 | varshini_12 |
| 1022230 | They don't have enough income | They said that they will try to fix it in the future | 1719675371 | varshini_12 |

**Root cause:** Double-submit bug in the application — same timestamp, same user, identical content.

**Current handling:** `stg_snapshot_stoplight_priority` deduplicates using `ROW_NUMBER() PARTITION BY snapshot_stoplight_id ORDER BY id`, keeping the earliest record.

**Note:** `snapshot_stoplight_achievement` has no duplicates, but the staging model applies the same defensive deduplication pattern.

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

**Current handling:** `fact_snapshots` recomputes `snapshot_number` using `ORDER BY snapshot_date, created_at, id`. This changes the sequence for 24K records.

**Note:** When ordering by `created_at`, the source `snapshot_number` matches 99.97% of records (only 275 mismatches).

**Open question:** Unknown whether source `snapshot_number` is assigned by `created_at` order, manual entry, or another mechanism.

**Recommendation:** Either drop snapshot_date from the model or fix the data quality issue in the source database.

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

---

## Orphaned Indicator Responses (Removed Indicators)

**Table:** `data_collect.snapshot_stoplight`
**Column:** `code_name`
**Related:** `data_collect.snapshot`, `data_collect.survey_stoplight`

Indicator responses exist for `code_name` values that no longer exist in the survey definition:

| Metric | Value |
|--------|-------|
| Total `snapshot_stoplight` records | 38,917,319 |
| Orphaned responses | 25,143 |
| Percentage | 0.065% |
| Distinct surveys affected | 22 |

Top orphaned indicators by volume:

| code_name | survey_definition_id | count |
|-----------|---------------------|-------|
| `insurance` | 147 | 6,761 |
| `culturalTraditionsAndHeritage` | 59 | 1,618 |
| `abilityToSolveProblemsAndConflicts` | 29 | 662 |
| `moralConscience` | 29 | 662 |
| `insurance` | 29 | 662 |

**Root cause:** Indicators were removed from survey definitions after responses had already been collected. For example, `insurance` exists in 170+ surveys but not in surveys 29, 118, 147.

**Impact:** These responses are silently dropped by the INNER JOIN in `fact_indicators_v2` when resolving `code_name` → `survey_indicator_id`. The data is lost from analytics.

**Current handling:** The fact table's CTE 1 (`stoplight_with_survey_indicator`) filters these out via INNER JOIN. No explicit handling needed.

**
---

## Historical Data Date Range

**Table:** `data_collect.snapshot`
**Column:** `snapshot_date`

**Issue:** Source data contains snapshots dating back to 2011 (`2011-10-25`), which is outside the default `dim_date` range (typically started at 2015).

**Impact:** ~24,000 snapshots failed foreign key integrity tests against `dim_date`.

**Model Handling:** `dim_date.sql` has been updated to generate dates starting from **2011-01-01** to accommodate this history.

---

## Families Without Organizations

**Table:** `ps_families.family`
**Column:** `organization_id`

**Issue:** 16 legacy family records have `NULL` `organization_id`.

**Impact:** Violates standard referential integrity expectations for the `dim_family` dimension.

**Model Handling:** The `not_null` test for `organization_id` in `schema.yml` has been set to `severity: warn` to allow the pipeline to proceed while flagging these known anomalies.

---

## Duplicate Indicator Definitions

**Table:** `data_collect.survey_stoplight`
**Columns:** `survey_definition_id`, `code_name`

**Issue:** Survey 80 has duplicate entries for the indicator code `socialcapital`.

**Impact:** Causes Cartesian products (fan-out) in joins when linking snapshots to indicators, resulting in duplicate rows in `fact_indicators`.

**Model Handling:** `stg_survey_stoplight.sql` now implements deduplication logic using `DISTINCT ON (survey_definition_id, code_name) ORDER BY updated_at DESC`, keeping only the most recently updated definition.

---

## Unused and Orphan Dimensions

**Table:** `data_collect.survey_stoplight_dimension`
**Column:** `status`

The dimension table contains 60 dimensions, but only 6 account for 99.7% of all family responses (~35.5M out of ~35.6M):

| Dimension | Responses | Families |
|-----------|-----------|----------|
| Housing and Infrastructure | 9,665,218 | 513,100 |
| Health and Environment | 7,625,167 | 509,523 |
| Education and Culture | 6,407,024 | 503,062 |
| Income and Employment | 4,986,835 | 512,800 |
| Interiority and Motivation | 3,772,597 | 575,954 |
| Organization and Participation | 3,033,038 | 573,876 |

The remaining 54 dimensions fall into three categories:

| Category | Count | Description |
|----------|-------|-------------|
| ORPHAN | 9 | Never linked to any indicator (test/placeholder dimensions) |
| DIRECT SURVEYS | 24 | Have survey indicators but no master templates (custom/ad-hoc) |
| LOW USAGE | 21 | Have both templates and surveys but minimal responses (<100K combined) |

Examples of orphan dimensions:
- `ANewDimension2.name`, `ANewDimensionTest.name` (test dimensions)
- `DimensionInvalida.name` (invalid placeholder)
- `Beliefs&Values.name`, `Physiological&BasicHumanNeeds.name` (created but never used)

**Impact:** Dashboard charts show many empty or near-empty dimension bars, cluttering visualizations.

**Ideal handling:** The source `status` field should be used to mark non-core dimensions as `INACTIVE`. Currently, most orphan dimensions are marked `ACTIVE` in the source, making the field unreliable for filtering.

**Current handling:** `stg_survey_stoplight_dimension.sql` implements a hardcoded `is_core_dimension` flag whitelisting the 6 primary poverty dimensions. `mart_indicators.sql` filters on this flag. This is a workaround — ideally the source system would maintain accurate `status` values.

**Recommendation:** Update the source application to set `status = 'INACTIVE'` for orphan/test dimensions, then replace the hardcoded whitelist with a filter on the source status field.

---

## Families Without Country

**Table:** `ps_families.family`
**Column:** `country`

**Issue:** 1,197 family records have `NULL` country, resulting in "Unknown" in the Surveys dashboard table.

| Metric | Value |
|--------|-------|
| Families without country | 1,197 |
| Total families | 595,347 |
| Percentage | 0.20% |
| Surveys affected | 1,184 |
| Surveys percentage | 0.12% |

Top affected organizations:

| Organization | Families | Actual Location |
|--------------|----------|-----------------|
| BANCAMIA | 489 | Colombia? |
| WARC Group | 208 | Unknown |
| Spring - Study Programme | 155 | UK |
| Newcastle Futures | 80 | UK |
| BANKOMUNALES | 74 | Unknown |

**Root cause:** These families were created without a country assignment in the source application.

**Organization fallback not viable:** The organization `country_code` field is unreliable — many UK/US organizations incorrectly default to `PY` (Paraguay):

| Organization | Has country_code | Actual Location |
|--------------|------------------|-----------------|
| Newcastle Futures | PY | UK |
| Gateshead OPA | PY | UK |
| CCE Chemung - Elmira US | PY | USA |
| Citizens Advice Newcastle | PY | UK |
| CARE USA | PY | USA |

**Current handling:** `mart_surveys.sql` uses `COALESCE(dim_family.country_name, 'Unknown')` to surface these records rather than hiding them.

**Recommendation:** Flag to platform team for source data cleanup. Given the low impact (0.12% of surveys), "Unknown" is an acceptable placeholder.

