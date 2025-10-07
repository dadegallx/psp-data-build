# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dbt project that creates a semantic layer for the Poverty Stoplight database, transforming raw operational data into analysis-ready models for LightDash BI tool. The project focuses on poverty measurement tracking, organizational performance monitoring, and indicator effectiveness analysis.

## Development Setup

**Prerequisites:**
- Python 3.8+
- uv package manager (preferred over pip)
- PostgreSQL database access to Poverty Stoplight database
- Node.js 18+ (for Lightdash deployment)

**Environment setup:**
```bash
uv sync                           # Install dependencies
source .venv/bin/activate         # Activate virtual environment
```

**Environment variables:** Create `.env` file in project root with:
```bash
export DBT_HOST="your-postgres-host"
export DBT_USER="your-username"
export DBT_PASSWORD="your-password"
export DBT_PORT="5432"
export DBT_DBNAME="your-database-name"
export DBT_SCHEMA="dbt_dev"
```

## Key Commands

**dbt Development:**
```bash
cd dbt                           # Navigate to dbt directory
source ../.env && dbt debug      # Test database connection
dbt compile                      # Check syntax without running
dbt run                         # Execute all models
dbt run --select model_name     # Run specific model
dbt run --select tag:working    # Run models by tag
dbt test                        # Run data quality tests
dbt docs generate && dbt docs serve  # Generate and serve documentation
```

**Python Development:**
```bash
uv add package_name              # Add new dependency
black .                         # Format code
isort .                         # Sort imports
flake8                          # Lint code
pytest                          # Run tests
```

## Architecture

**Database Schemas:**
- `ps_network` - Organization and application data
- `data_collect` - Survey definitions, responses, snapshots
- `ps_families` - Family master data
- `library` - Reference data (future use)
- `ps_solutions` - Solutions data (future use)

**dbt Project Structure:**
```
dbt/
├── models/
│   ├── _sources.yml           # Source table definitions
│   ├── staging/               # Raw data cleaning models
│   └── marts/                 # Final semantic layer models
├── dbt_project.yml           # Project configuration
└── profiles.yml              # Database connection profiles
```

## Key Business Logic

**Timestamp Handling:** Most timestamps stored as bigint milliseconds - use `TO_TIMESTAMP(field/1000)` for conversion.

**Survey Rounds:**
- `snapshot_number = 1` indicates baseline survey
- `snapshot_number > 1` indicates follow-up surveys
- Use `is_last = true` for current family status

**Poverty Scoring:**
- Red (1) = Critical poverty
- Yellow (2) = Moderate poverty/vulnerability
- Green (3) = Non-poor
- Score calculation: `(green×3 + yellow×2 + red×1) / (total×3)`

**Anonymous Data:** When `anonymous = true`, personal fields contain 'ANON_DATA'

## YAML Schema Syntax

### Staging models
  - name: stg_orders
    description: "Cleaned orders from raw source"
    columns:
      - name: order_id
        data_tests: [not_null, unique]

### Mart models
  - name: orders
    description: "Order facts for analysis"
    columns:
      - name: order_key
        data_tests: [not_null, unique]
      - name: customer_key
        data_tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_key\
\
Use this simplified schema when creating the YAML file for dbt models. Limit yourself to columns and some simple data tests (the data tests only if explicitly requested). Do not overcomplicate it.

## dbt Model Configuration

**Basic Configuration:**
```sql
-- In model SQL files
{{ config(
    materialized="view",
    tags=["staging"]
) }}

select * from {{ source('data_collect', 'snapshot') }}
```

**Materialization Options:**
- `view` - Default for staging and development (fast, no storage cost)
- `table` - For production marts requiring performance (slower build, faster queries)
- `incremental` - For large datasets with new/updated records only

**Configuration Inheritance:**
```yaml
# dbt_project.yml
models:
  psp_data_build:
    staging:
      +materialized: view
      +tags: ["staging"]
    marts:
      +materialized: view  # Can override in individual models
      +tags: ["mart", "semantic_layer"]
```

## Model Development Guidelines

**Naming Conventions:**
- `stg_` prefix for staging models (e.g., `stg_snapshots`, `stg_families`)
- `int_` prefix for intermediate models (transformations between staging and marts)
- `fct_` prefix for fact tables (events, transactions, measurements)
- `dim_` prefix for dimension tables (entities, lookups, categories)

**SQL Style Guide:**
```sql
-- Use CTEs for readability
with base_data as (
    select
        id,
        family_id,
        snapshot_date,
        is_last
    from {{ source('data_collect', 'snapshot') }}
),

filtered_data as (
    select *
    from base_data
    where is_last = true
)

select * from filtered_data
```

**Model References:**
```sql
-- Reference other models
select * from {{ ref('stg_snapshots') }}

-- Reference source tables
select * from {{ source('data_collect', 'snapshot') }}

-- Use fully qualified names in documentation
-- {{ source('schema_name', 'table_name') }}
-- {{ ref('model_name') }}
```

## dbt Testing Framework

**Generic Tests in schema.yml:**
```yaml
models:
  - name: stg_snapshots
    columns:
      - name: id
        data_tests: [not_null, unique]
      - name: family_id
        data_tests:
          - not_null
          - relationships:
              to: ref('stg_families')
              field: family_id
      - name: snapshot_number
        data_tests:
          - accepted_values:
              values: [1, 2, 3, 4, 5]
```

**Singular Tests:**
- Create custom SQL tests in `tests/` directory
- Test business logic specific to poverty assessment data
- Example: `tests/assert_baseline_surveys_exist.sql`

## Incremental Models

**Basic Incremental Configuration:**
```sql
{{ config(
    materialized="incremental",
    unique_key="id"
) }}

select
    id,
    family_id,
    snapshot_date,
    created_at
from {{ source('data_collect', 'snapshot') }}

-- Only process new records on incremental runs
{% if is_incremental() %}
    where created_at > (select max(created_at) from {{ this }})
{% endif %}
```

**Handling Late-Arriving Data:**
```sql
{% if is_incremental() %}
    -- Look back 3 days to catch late-arriving records
    where snapshot_date >= (
        select dateadd('day', -3, max(snapshot_date))
        from {{ this }}
    )
{% endif %}
```

**Merge Strategies:**
- `unique_key` - Use primary key for upsert behavior
- Handle timestamp-based incremental loads for survey data
- Consider using `snapshot_date` or `created_at` for incremental logic

## Documentation Standards

**Model Documentation:**
- Keep schema.yml files alongside model SQL files
- The YAML filename can be anything (`schema.yml`, `_models.yml`, etc.)
- The `name` field in YAML must exactly match the SQL filename (without .sql)
- One schema.yml file can document multiple models
- Document all models with clear descriptions
- Focus on business meaning, not just technical details

**Essential Column Documentation:**
```yaml
models:
  - name: stg_families
    description: "Cleaned family records from poverty assessment surveys"
    columns:
      - name: family_id
        description: "Unique identifier for each family"
        data_tests: [not_null, unique]
      - name: is_anonymous
        description: "Privacy flag indicating if personal data is anonymized"
```

**Source Freshness:**
```yaml
sources:
  - name: data_collect
    description: "Survey data collection tables"
    freshness:
      warn_after: {count: 1, period: day}
      error_after: {count: 3, period: day}
    tables:
      - name: snapshot
        description: "Survey snapshot records"
```

## Database Structure

The source database consists of five main schemas containing poverty assessment data:
- `ps_network` - Organizational hierarchy (applications, organizations)
- `data_collect` - Survey definitions, responses, and snapshots
- `ps_families` - Family and member information
- `library` - Reference data for indicators
- `ps_solutions` - Intervention solutions

**For detailed schema documentation**, see `docs/SCHEMA.md` or `docs/SCHEMA-friendly.md`

## Key Relationships & Data Patterns

### Template-Instance Architecture
- **survey_stoplight_indicator**: Master template catalog (346 reusable indicator templates)
- **survey_stoplight**: Survey-specific implementations (20,081+ records, customized per survey)
- **Relationship**: `survey_stoplight.survey_stoplight_indicator_id → survey_stoplight_indicator.id`
- **Pattern**: One template can be used by multiple surveys with customization

### Organizational Hierarchy
- **Applications** (`ps_network.applications`): Hub/platform definitions (e.g., "Hub 52 Unbound")
- **Organizations** (`ps_network.organizations`): Implementing organizations within applications
- **Families** (`ps_families.family`): End beneficiaries served by organizations
- **Key Insight**: Organizations can exist without families (e.g., Organization 323 "Kuxtal Org")

### Privacy & Anonymization Patterns
- **Anonymous Flag**: When `anonymous=true`, personal data appears as 'ANON_DATA'
- **Affected Fields**: `name`, `first_name`, `last_name`, `gender` show 'ANON_DATA' when anonymous
- **Privacy Indicators**: Look for `anonymous` boolean fields across tables

### Survey Progression & Engagement
- **Current Status**: Use `is_last=true` to identify most recent family surveys
- **Survey Rounds**: `snapshot_number = 1` for baseline, `>1` for follow-ups
- **Engagement Reality**: Follow-up rates typically very low (0-9% range)
- **Data Quality**: Expect significant survey dropout between baseline and follow-up\

## Database Access

**Source Database:** Neon PostgreSQL (Project ID: `soft-brook-12834941`)

**Access Methods:**
1. **Via Neon MCP Tool** (Recommended): Use Claude's Neon MCP integration to query the database directly
   - Example: `mcp__neon__run_sql` with `projectId: "soft-brook-12834941"`
   - Example: `mcp__neon__describe_table_schema` to inspect schema structure

2. **Via Connection String**: Get current credentials using:
   ```bash
   # Get connection string via Neon MCP
   mcp__neon__get_connection_string(projectId: "soft-brook-12834941")
   ```

**IMPORTANT:** Do NOT make changes to the source database. Use database access only to:
- Inspect table schemas and relationships
- Query data for analysis and model design
- Validate dbt model logic
- Test transformations before implementing in dbt