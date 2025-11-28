# Poverty Stoplight Data Model Documentation

This directory contains the complete data modeling documentation for the Poverty Stoplight data warehouse project.

---

## Documentation Index

### 1. Business Requirements
📄 **[schema_docs/BUSINESS_QUESTIONS_DOCS.md](./schema_docs/BUSINESS_QUESTIONS_DOCS.md)**
- 20 business questions organized by analytical theme
- Complete metrics catalog (family-indicator-snapshot and family-snapshot levels)
- Comprehensive dimensions catalog (slice-by attributes)
- Dashboard-specific notes and business rules

**Use this to:** Understand what questions the data warehouse needs to answer

---

### 2. Star Schema Reference (Single Source of Truth)
📄 **[schema_docs/SCHEMA_REFERENCE.md](./schema_docs/SCHEMA_REFERENCE.md)**
- Complete column specifications for all tables
- Data types, constraints, and indexes
- Source-to-target mappings
- Data quality rules and NULL handling
- Entity Relationship Diagram (ERD)
- SCD types and design patterns

**Use this to:** Implement dbt models and understand technical specifications

---

### 3. Raw Source Schema
📄 **[raw_data_collect_docs/RAW_SCHEMA.md](./raw_data_collect_docs/RAW_SCHEMA.md)**
- Complete raw database schema documentation
- All source tables across 5 schemas
- Key relationships and data patterns
- Template-instance architecture explained

**Use this to:** Understand the source system structure

📄 **[raw_data_collect_docs/RAW_SCHEMA_DOCS.md](./raw_data_collect_docs/RAW_SCHEMA_DOCS.md)**
- Simplified, business-friendly overview of raw schema
- Core structure and key concepts
- Data patterns to understand

**Use this to:** Get a quick understanding of the source system (non-technical)

---

## Key Design Principles

### 1. Atomic Grain Star Schemas
- **Two fact tables** at atomic grain sharing common dimensions
- Stoplight indicators: family-indicator-snapshot grain
- Economic questions: family-question-snapshot grain
- All aggregations derived from these atomic fact tables

### 2. Dimensional Modeling (Kimball)
- Star schema design (not snowflake)
- Denormalized dimensions with hierarchies
- Type 1 slowly changing dimensions (overwrite)
- Degenerate dimensions in fact tables where appropriate

### 3. Business-Friendly Design
- Descriptive dimension names (not cryptic codes)
- Clear hierarchies (Application > Organization, Dimension > Indicator)
- Human-readable attributes in dimensions

### 4. Query Performance
- Narrow fact tables with appropriate indexes
- Wide dimension tables with rich descriptive attributes
- Strategic indexing on filter and join columns

---

## Data Model Summary

### Fact Tables

**fact_family_indicator_snapshot**
- **Grain:** One row per family, per indicator, per snapshot
- **Measures:** indicator_status_value (1=Red, 2=Yellow, 3=Green, NULL=Skipped)
- **Degenerate Dimensions:** snapshot_id, snapshot_number, is_last

**fact_family_economic_snapshot**
- **Grain:** One row per family, per economic question, per snapshot
- **Measures:** value_text, value_number, value_date, value_other_text, currency_code
- **Degenerate Dimensions:** snapshot_id, snapshot_number, is_last, answer_type

### Dimension Tables (6)

1. **dim_date** - Survey dates (standard date dimension)
2. **dim_organization** - Organizations + Applications hierarchy
3. **dim_indicator** - Indicators + Dimensions hierarchy
4. **dim_family** - Family identity + Geography
5. **dim_survey_definition** - Survey templates
6. **dim_economic_questions** - Economic question metadata

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-01-06 | Initial star schema design | Claude + Davide |
| 1.1 | 2025-01-28 | Added economic fact table, consolidated docs | Claude + Davide |

---

## File Structure

```
data_model/
├── README.md                          # This file
├── schema_docs/
│   ├── BUSINESS_QUESTIONS_DOCS.md     # Business requirements
│   └── SCHEMA_REFERENCE.md            # Complete technical reference + ERD
├── raw_data_collect_docs/
│   ├── RAW_SCHEMA.md                  # Detailed raw schema
│   └── RAW_SCHEMA_DOCS.md             # Simplified raw schema
└── tableau_screenshots/               # Source dashboard screenshots
```
