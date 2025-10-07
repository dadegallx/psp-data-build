# Mart Models

This folder contains the final semantic layer models ready for analytics and BI tools.

## Naming Convention
- Fact tables: `fct_` prefix (e.g., `fct_survey_responses.sql`)
- Dimension tables: `dim_` prefix (e.g., `dim_families.sql`)
- Wide/denormalized tables: descriptive names (e.g., `family_poverty_tracking.sql`)

## Purpose
Mart models contain:
- Business logic and calculations
- Aggregations and metrics
- Joins between staging models
- Final structure optimized for analysis
- Documentation for business users

These models are what end users will query directly through Lightdash or other BI tools.