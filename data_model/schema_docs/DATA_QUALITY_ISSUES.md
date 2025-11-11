# Data Quality Issues

## Issue 1: Missing FK in snapshot_stoplight

**Problem:** `data_collect.snapshot_stoplight` lacks a direct FK to `data_collect.survey_stoplight`.

**Impact:** Cannot directly link indicator responses to their definitions. Must join via code_name which created 84.7M row cartesian product (270x expected size).

**Solution:** Derive `indicator_id` via FK chain: `snapshot_stoplight → snapshot → survey_stoplight` using both `survey_definition_id` and `code_name`.

**Result:** Clean 1:1 join, ~307K rows (expected size).

---

## Issue 2: Duplicate code_names in Surveys

**Problem:** 9 rows (0.003%) have duplicate `code_name` within same `survey_definition_id`.

**Example:** Survey 493 has two indicators with `code_name = "abilityToSolveProblemsAndConflicts"`:
- indicator_id 19219 ("Conflict", order_number 30)
- indicator_id 22803 ("Relation", order_number 35)

**Solution:** Pick first indicator by `order_number` (lowest = first presented in survey).

**Impact:** Minimal - affects <0.01% of data. Documented in `stg_snapshot_stoplight` model.
