# Data Quality Issues and Resolutions

## Overview

This document tracks known data quality issues in the Poverty Stoplight source database and how they are handled in the dbt transformation pipeline.

---

## Stoplight Indicator Issues

### Issue 1: Missing FK in snapshot_stoplight

**Problem:** `data_collect.snapshot_stoplight` lacks a direct FK to `data_collect.survey_stoplight`.

**Impact:** Cannot directly link indicator responses to their definitions. Must join via code_name which created 84.7M row cartesian product (270x expected size).

**Solution:** Derive `indicator_id` via FK chain: `snapshot_stoplight → snapshot → survey_stoplight` using both `survey_definition_id` and `code_name`.

**Result:** Clean 1:1 join, ~307K rows (expected size).

**Location in Pipeline:**
- Implemented in: `dbt/models/staging/stg_snapshot_stoplight.sql`
- Logic: `inner join survey_stoplight on survey_definition_id + code_name`

---

### Issue 2: Duplicate code_names in Surveys

**Problem:** 9 rows (0.003%) have duplicate `code_name` within same `survey_definition_id`.

**Example:** Survey 493 has two indicators with `code_name = "abilityToSolveProblemsAndConflicts"`:
- indicator_id 19219 ("Conflict", order_number 30)
- indicator_id 22803 ("Relation", order_number 35)

**Solution:** Pick first indicator by `order_number` (lowest = first presented in survey).

**Impact:** Minimal - affects <0.01% of data. Documented in `stg_snapshot_stoplight` model.

**Location in Pipeline:**
- Implemented in: `dbt/models/staging/stg_snapshot_stoplight.sql`
- Logic: `row_number() over (partition by survey_definition_id, code_name order by order_number) = 1`

---

## Economic Data Issues

### Orphaned Economic Response Code Names

**Issue:** 244 unique `code_name` values in `snapshot_economic` table do not have matching definitions in `survey_economic` table.

**Impact:**
- Responses for these code_names cannot be linked to question metadata (question text, answer type, etc.)
- Affects data completeness for economic indicators
- Unknown which survey versions or families are affected

**Current Resolution:**
- **Filtering Approach**: `stg_snapshot_economic` uses an **inner join** to `survey_economic`, which **excludes** all orphaned responses from the semantic layer
- Orphaned responses are documented but not analyzed in marts layer
- This ensures referential integrity between facts and dimensions

**Location in Pipeline:**
- Filtering occurs in: `dbt/models/staging/stg_snapshot_economic.sql`
- Logic: `inner join survey_economic on survey_definition_id + code_name`

**Examples of Orphaned Code Names:**
(Add examples here once analysis is performed)

**Recommended Investigation:**
1. Query source database to identify which code_names are orphaned
2. Cross-reference with survey versions to determine if they are:
   - Legacy code_names from deprecated questions
   - Typos or data entry errors
   - Valid code_names that should be added to `survey_economic`
3. Determine if orphaned responses should be:
   - Backfilled into `survey_economic` (if valid)
   - Corrected at source (if typos)
   - Documented as legacy data (if deprecated)

**SQL to Identify Orphaned Code Names:**
```sql
-- Find orphaned code_names in snapshot_economic
SELECT DISTINCT se.code_name
FROM data_collect.snapshot_economic se
WHERE NOT EXISTS (
    SELECT 1
    FROM data_collect.survey_economic sve
    INNER JOIN data_collect.snapshot s ON s.id = se.snapshot_id
    WHERE sve.survey_definition_id = s.survey_definition_id
      AND sve.code_name = se.code_name
)
ORDER BY se.code_name;

-- Count affected responses by code_name
SELECT
    se.code_name,
    COUNT(*) as orphaned_response_count,
    COUNT(DISTINCT se.snapshot_id) as affected_snapshots,
    MIN(se.created_date) as first_occurrence,
    MAX(se.created_date) as last_occurrence
FROM data_collect.snapshot_economic se
WHERE NOT EXISTS (
    SELECT 1
    FROM data_collect.survey_economic sve
    INNER JOIN data_collect.snapshot s ON s.id = se.snapshot_id
    WHERE sve.survey_definition_id = s.survey_definition_id
      AND sve.code_name = se.code_name
)
GROUP BY se.code_name
ORDER BY orphaned_response_count DESC;
```

---

### Economic Answer Type Inconsistency

**Issue:** Economic survey fields use `answer_type = 'string'` for all data types, including numeric and date fields.

**Impact:**
- All 3,318 `householdMonthlyIncome` responses stored with `answer_type = 'string'` (should be 'number')
- All 1,472 currency code responses stored with `answer_type = 'string'` (acceptable for currency codes)
- Numeric values like "8000" stored in `value` column as text rather than being typed appropriately

**Data Pattern:**
- Income responses: 3,318 records with `answer_type = 'string'`, value contains numeric strings
- Currency responses: 1,472 records with `answer_type = 'string'`, value contains ISO currency codes
- Both fields exist across 1,386 snapshots (overlapping)
- Income-only: 1,932 snapshots (no currency specified)
- Currency-only: 86 snapshots (unusual - currency without income amount)

**Solution:** Enhanced staging model to handle numeric conversion from string type.

**Implementation:**
- Added `'string'` to numeric conversion logic in `stg_snapshot_economic.sql`
- Validates numeric format with regex before conversion: `value ~ '^[0-9]+\.?[0-9]*$'`
- Converts valid numeric strings to `answer_number` column for downstream use

**Location in Pipeline:**
- Implemented in: `dbt/models/staging/stg_snapshot_economic.sql`
- Logic: `when answer_type in ('number', 'string') and value ~ '^[0-9]+\.?[0-9]*$' then value::numeric`

**Test Coverage:**
- Added `'string'` to `accepted_values` test for `answer_type` in `dim_economic_questions`
- Removed income-currency pairing test (incompatible with atomic grain design where income and currency are separate rows)

---

## Stoplight Indicator Issues

(Document any stoplight-specific data quality issues here in the future)

---

## Survey Definition Issues

(Document any survey definition data quality issues here in the future)

---

## Resolution Status Legend

- **Filtered**: Data excluded from semantic layer via inner joins or WHERE clauses
- **Flagged**: Data included but marked with quality indicator column
- **Corrected**: Data transformed to fix known issue
- **Documented**: Issue noted but not yet resolved, under investigation

---

## Change Log

| Date | Issue | Status | Action Taken |
|------|-------|--------|--------------|
| 2025-01-14 | Orphaned economic code_names | Filtered | Added inner join in stg_snapshot_economic |
