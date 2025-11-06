# Poverty Stoplight Data Model Documentation

This directory contains the complete data modeling documentation for the Poverty Stoplight data warehouse project.

---

## Documentation Index

### 1. Business Requirements
📄 **[BUSINESS_QUESTIONS_DOCS.md](./BUSINESS_QUESTIONS_DOCS.md)**
- 20 business questions organized by analytical theme
- Complete metrics catalog (family-indicator-snapshot and family-snapshot levels)
- Comprehensive dimensions catalog (slice-by attributes)
- Dashboard-specific notes and business rules

**Use this to:** Understand what questions the data warehouse needs to answer

---

### 2. Star Schema Design
📄 **[STAR_SCHEMA_DESIGN.md](./STAR_SCHEMA_DESIGN.md)**
- Complete star schema design at family-indicator-snapshot grain
- Detailed fact table design with degenerate dimensions
- Five dimension tables with hierarchies
- Design decisions and rationale
- Data volume estimates

**Use this to:** Understand the overall data warehouse architecture

---

### 3. Entity Relationship Diagram
📄 **[STAR_SCHEMA_ERD.md](./STAR_SCHEMA_ERD.md)**
- Mermaid ERD diagram showing all tables and relationships
- Classic Kimball star schema visualization
- Relationship cardinalities explained
- Dimension hierarchies illustrated
- Key attributes for common queries

**Use this to:** Visualize the data model and understand table relationships

---

### 4. Detailed Schema Reference
📄 **[SCHEMA_REFERENCE.md](./SCHEMA_REFERENCE.md)**
- Complete column specifications for all tables
- Data types, constraints, and indexes
- Source-to-target mappings
- Data quality rules
- NULL handling strategy

**Use this to:** Implement dbt models and understand technical specifications

---

### 5. Raw Source Schema
📄 **[raw_data_collect/RAW_SCHEMA.md](./raw_data_collect/RAW_SCHEMA.md)**
- Complete raw database schema documentation
- All source tables across 5 schemas
- Key relationships and data patterns
- Template-instance architecture explained

**Use this to:** Understand the source system structure

📄 **[raw_data_collect/RAW_SCHEMA-DOCS.md](./raw_data_collect/RAW_SCHEMA-DOCS.md)**
- Simplified, business-friendly overview of raw schema
- Core structure and key concepts
- Data patterns to understand

**Use this to:** Get a quick understanding of the source system (non-technical)

---

## Key Design Principles

### 1. Single Source of Truth
- **One star schema** at the atomic grain (family-indicator-snapshot)
- All aggregations can be derived from this single fact table
- No data duplication across multiple fact tables

### 2. Dimensional Modeling (Kimball)
- Star schema design (not snowflake)
- Denormalized dimensions with hierarchies
- Type 1 slowly changing dimensions (overwrite)
- Degenerate dimensions in fact table where appropriate

### 3. Business-Friendly Design
- Descriptive dimension names (not cryptic codes)
- Clear hierarchies (Application > Organization, Dimension > Indicator)
- Human-readable attributes in dimensions

### 4. Query Performance
- Narrow fact table with appropriate indexes
- Wide dimension tables with rich descriptive attributes
- Strategic indexing on filter and join columns

---

## Data Model Summary

### Fact Table
**fact_family_indicator_snapshot**
- **Grain:** One row per family, per indicator, per snapshot
- **Measures:** indicator_status_value (1=Red, 2=Yellow, 3=Green, NULL=Skipped)
- **Degenerate Dimensions:** snapshot_id, snapshot_number, is_last
- **Volume:** ~225K rows currently, growing ~75K per 1,000 families

### Dimension Tables

1. **dim_date** - Survey dates (standard date dimension)
2. **dim_organization** - Organizations + Applications hierarchy
3. **dim_indicator** - Indicators + Dimensions hierarchy
4. **dim_family** - Family identity + Geography
5. **dim_survey_definition** - Survey templates

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-01-06 | Initial star schema design | Claude + Davide |

---

## File Structure

```
data_model/
├── README.md                          # This file
├── BUSINESS_QUESTIONS_DOCS.md         # Business requirements
├── STAR_SCHEMA_DESIGN.md              # Architecture overview
├── STAR_SCHEMA_ERD.md                 # Visual diagrams
├── SCHEMA_REFERENCE.md                # Technical specifications
├── raw_data_collect/
│   ├── RAW_SCHEMA.md                  # Detailed raw schema
│   └── RAW_SCHEMA-DOCS.md             # Simplified raw schema
└── tableau_screenshots/               # Source dashboard screenshots
    ├── dimensions_overview/
    ├── stoplight_overview/
    ├── map_overview/
    └── survey_stoplight_comparison/
```
