# Data Quality Issues in Poverty Stoplight Database

## Summary
The staging layer surfaced a critical data quality issue where some surveys contain duplicate indicator definitions. This document outlines the issue, impact, and handling approach.

## Issue: Duplicate Indicator Definitions

### Problem Description
Three surveys contain duplicate `(survey_definition_id, code_name)` combinations in the `survey_stoplight` table:

| Survey ID | Code Name | Conflicting Names | Impact |
|-----------|-----------|-------------------|---------|
| 87 | socialCapital | Group Activities, Social Capital | Minimal |
| 493 | abilityToSolveProblemsAndConflicts | Conflict, Relation | 7 snapshots, 7 responses |
| 627 | abilityToSolveProblemsAndConflicts | Konflik, Relasi | 1 snapshot, 2 responses |

### Data Impact
- **Total Impact**: 8 snapshots (0.08%) and 9 responses (0.003%)
- **Business Impact**: Minimal - affects <0.1% of data
- **Analysis Impact**: Ambiguous mappings require handling in downstream models

## Staging Layer Solution

### Models Created
1. **`stg_indicator_quality_issues`**: Identifies all duplicate cases
2. **Enhanced `stg_indicators_definitions`**: Adds `definition_rank` and `definition_count`
3. **Enhanced `stg_snapshot_indicator`**: Adds `mapping_quality` flag

### Quality Monitoring
- **Data Tests**: Alert on new duplicates via dbt tests
- **Quality Flag**: `mapping_quality='ambiguous'` marks affected responses
- **Documentation**: Clear warnings in model descriptions

## Recommended Handling Strategies

### For Analysis Models
1. **Default Strategy**: Filter to `definition_rank = 1` (first occurrence)
2. **Aggregation**: Group by survey and indicator when specific definition doesn't matter
3. **Business Critical**: Flag for manual review

### Example Usage
```sql
-- Safe join that handles duplicates
SELECT *
FROM {{ ref('stg_snapshot_indicator') }} si
JOIN {{ ref('stg_indicators_definitions') }} def
    ON si.code_name = def.code_name
    AND si.survey_definition_id = def.survey_definition_id
    AND def.definition_rank = 1  -- Take first occurrence
```

## Monitoring
- dbt tests will fail if new duplicate patterns emerge
- Quality dashboard should track `mapping_quality` distribution
- Monthly review of `stg_indicator_quality_issues` for new cases

## Business Recommendation
Consider data governance process to prevent future duplicates during survey setup.