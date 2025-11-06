# Poverty Stoplight dbt Project

## Overview

This dbt project implements a star schema data warehouse for the Poverty Stoplight program, transforming raw operational data into an analysis-ready semantic layer.

**Star Schema Design:** One fact table + 5 dimension tables
**Grain:** Family-Indicator-Snapshot (one row per family, per indicator, per survey)
**Documentation:** See `../data_model/` for complete star schema design specifications

## Project Structure

```
dbt/
├── models/
│   ├── _sources.yml              # Source table definitions
│   ├── staging/                  # Staging layer (9 models)
│   │   ├── stg_applications.sql
│   │   ├── stg_organizations.sql
│   │   ├── stg_families.sql
│   │   ├── stg_family_members.sql
│   │   ├── stg_snapshots.sql
│   │   ├── stg_snapshot_stoplight.sql
│   │   ├── stg_survey_definitions.sql
│   │   ├── stg_survey_stoplight.sql
│   │   ├── stg_survey_stoplight_indicator.sql
│   │   └── schema.yml
│   └── marts/                    # Semantic layer (6 models)
│       ├── dim_date.sql
│       ├── dim_organization.sql
│       ├── dim_indicator.sql
│       ├── dim_family.sql
│       ├── dim_survey_definition.sql
│       ├── fact_family_indicator_snapshot.sql
│       └── schema.yml
├── macros/                       # Custom Jinja macros
├── tests/                        # Custom SQL tests
├── data/                         # Seed data
├── dbt_project.yml              # Project configuration
├── profiles.yml                 # Database connection
└── packages.yml                 # External packages (dbt_utils)
```

## Star Schema

### Fact Table
**fact_family_indicator_snapshot**
- Grain: One row per family, per indicator, per snapshot
- ~225,000 rows currently
- Measures: indicator_status_value (1=Red, 2=Yellow, 3=Green, NULL=Skipped)

### Dimension Tables
1. **dim_date** - Standard date dimension (~7,300 rows)
2. **dim_organization** - Organizational hierarchy with Applications (~100-500 rows)
3. **dim_indicator** - Indicators with Dimension categories (~500-1,000 rows)
4. **dim_family** - Family identity and geography (~3,000-10,000 rows)
5. **dim_survey_definition** - Survey templates (~20-50 rows)

## Getting Started

### Prerequisites
- Python 3.8+ with dbt-core and dbt-postgres installed
- PostgreSQL database access to Poverty Stoplight database
- Environment variables configured (see below)

### Environment Setup

Create `.env` file in project root:
```bash
export DBT_HOST="your-postgres-host"
export DBT_USER="your-username"
export DBT_PASSWORD="your-password"
export DBT_PORT="5432"
export DBT_DBNAME="your-database-name"
export DBT_SCHEMA="dbt_dev"
```

Load environment variables:
```bash
source ../.env
```

### Initial Setup

```bash
cd dbt

# Install dbt packages (dbt_utils)
dbt deps

# Test database connection
dbt debug

# Compile SQL (syntax check)
dbt compile
```

### Running Models

```bash
# Run all models (staging → dimensions → fact)
dbt run

# Run specific layer
dbt run --select staging
dbt run --select marts

# Run specific model and its dependencies
dbt run --select +fact_family_indicator_snapshot

# Full refresh (drop and recreate tables)
dbt run --full-refresh
```

### Testing Data Quality

```bash
# Run all tests
dbt test

# Test specific model
dbt test --select fact_family_indicator_snapshot

# Test with warnings (don't fail on warnings)
dbt test --warn-error
```

### Documentation

```bash
# Generate documentation
dbt docs generate

# Serve documentation locally (opens at http://localhost:8080)
dbt docs serve
```

## Key Technical Details

### Timestamp Conversion
Source timestamps stored as bigint milliseconds:
```sql
to_timestamp(field / 1000)
```

### Date Key Generation
Date dimension uses YYYYMMDD format:
```sql
to_char(date_field, 'YYYYMMDD')::integer
```

### Surrogate Key Generation
Using dbt_utils.generate_surrogate_key():
```sql
{{ dbt_utils.generate_surrogate_key(['col1', 'col2']) }}
```

### Anonymization Handling
Family names show 'ANON_DATA' when anonymous flag is true:
```sql
case when anonymous then 'ANON_DATA' else name end
```

### Country Derivation
Family country derived from first family member's birth_country:
```sql
first_value(birth_country) over (
    partition by family_id
    order by created_at
)
```

## Model Materialization Strategy

- **Staging models:** Views (lightweight, no storage cost)
- **Dimension models:** Tables (performance-optimized for joins)
- **Fact model:** Table (full refresh, performance-optimized)

## Data Patterns

### Current Status Analysis
Filter for most recent survey per family:
```sql
WHERE is_last = TRUE
```

### Baseline vs Follow-up
- Baseline: `WHERE snapshot_number = 1`
- Follow-ups: `WHERE snapshot_number > 1`

### Progress Analysis
Compare same family across surveys:
```sql
-- Baseline indicators
WHERE family_key = X AND snapshot_number = 1

-- Latest indicators
WHERE family_key = X AND is_last = TRUE
```

### Poverty Scoring
- Red (1) = Critical poverty
- Yellow (2) = Moderate poverty/vulnerability
- Green (3) = Non-poor
- NULL = Indicator skipped

## Troubleshooting

### Connection Issues
```bash
# Verify environment variables
echo $DBT_HOST $DBT_USER $DBT_DBNAME $DBT_SCHEMA

# Test connection
dbt debug
```

### Compilation Errors
```bash
# Check for syntax errors
dbt compile

# View compiled SQL
cat target/compiled/psp_data_build/models/marts/fact_family_indicator_snapshot.sql
```

### Test Failures
```bash
# Run tests with details
dbt test --store-failures

# View failed test results in target/
cat target/run_results.json
```

### Performance Issues
```bash
# Check model execution times
dbt run --profiles-dir . | grep "Completed"

# View query execution plan
dbt compile --select fact_family_indicator_snapshot
# Then EXPLAIN the compiled SQL in PostgreSQL
```

## Next Steps

After successful dbt build:
1. Connect LightDash to dbt models for BI layer
2. Define semantic metrics using MetricFlow
3. Add incremental loading for fact table (optional optimization)
4. Set up CI/CD for production deployments

## Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [Star Schema Design Docs](../data_model/STAR_SCHEMA_DESIGN.md)
- [Schema Reference](../data_model/SCHEMA_REFERENCE.md)
- [Business Questions](../data_model/BUSINESS_QUESTIONS_DOCS.md)
