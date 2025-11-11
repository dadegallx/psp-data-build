# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dbt project that creates a star schema semantic layer for the Poverty Stoplight database, transforming raw operational data into analysis-ready models for BI data visualisation. The project focuses on poverty measurement tracking, organizational performance monitoring, and indicator effectiveness analysis.

**Key Technologies:**
- dbt-core 1.7+ with PostgreSQL adapter
- Python 3.8+ with uv package manager
- dbt_utils package (v1.1.1)
- Neon PostgreSQL database (Project ID: `soft-brook-12834941`)

## Development Setup

**Prerequisites:**
- Python 3.8+
- uv package manager (always use `uv` instead of `pip` for this project)
- PostgreSQL database access

**Initial Setup:**
```bash
uv sync                          # Install dependencies from pyproject.toml
source .venv/bin/activate        # Activate virtual environment
cp .env.template .env            # Create environment file
# Edit .env with your database credentials
```

**Environment Variables (.env):**
```bash
export DBT_HOST="your-postgres-host"
export DBT_USER="your-username"
export DBT_PASSWORD="your-password"
export DBT_PORT="5432"
export DBT_DBNAME="your-database-name"
export DBT_SCHEMA="dbt_dev"      # Your development schema
```

## Common Commands

**dbt Workflow (must be run from `/dbt` directory):**
```bash
cd dbt                                    # Navigate to dbt directory
source ../.env && dbt debug               # Test database connection
dbt compile                               # Check syntax without running
dbt run                                   # Execute all models
dbt run --select model_name               # Run specific model
dbt run --select tag:staging              # Run models by tag
dbt test                                  # Run data quality tests
dbt test --select model_name              # Test specific model
dbt docs generate && dbt docs serve       # Generate and serve documentation
dbt deps                                  # Install dbt packages (after editing packages.yml)
```

**Python Development (from project root):**
```bash
uv add package_name              # Add new dependency
uv sync                          # Sync dependencies after changes
black .                          # Format code
isort .                          # Sort imports
flake8                           # Lint code
pytest                           # Run tests
```

## Project Architecture

**Source Database Schemas:**
- `ps_network` - Organizational hierarchy (applications, organizations)
- `data_collect` - Survey definitions, responses, snapshots
- `ps_families` - Family and member information
- `library` - Reference data for indicators (future use)
- `ps_solutions` - Intervention solutions (future use)

**dbt Project Structure:**
```
dbt/
├── models/
│   ├── _sources.yml                    # Source table definitions for all schemas
│   ├── staging/                        # Cleaning layer (views)
│   │   ├── schema.yml                  # Documentation and tests
│   │   ├── stg_applications.sql
│   │   ├── stg_families.sql
│   │   ├── stg_organizations.sql
│   │   ├── stg_snapshots.sql
│   │   ├── stg_snapshot_stoplight.sql
│   │   ├── stg_survey_definitions.sql
│   │   ├── stg_survey_stoplight.sql
│   │   └── stg_survey_stoplight_indicator.sql
│   └── marts/                          # Star schema (tables)
│       ├── schema.yml                  # Documentation and tests
│       ├── dim_date.sql                # Date dimension
│       ├── dim_family.sql              # Family dimension (SCD Type 2)
│       ├── dim_indicator.sql           # Indicator dimension
│       ├── dim_organization.sql        # Organization dimension
│       ├── dim_survey_definition.sql   # Survey definition dimension
│       └── fact_family_indicator_snapshot.sql  # Fact table
├── tests/                              # Custom SQL tests
├── macros/                             # Reusable SQL macros
├── data/                               # Seed CSV files
├── dbt_project.yml                     # Project configuration
├── profiles.yml                        # Database connection profiles
└── packages.yml                        # External dbt packages
```

**Star Schema Design:**
- **Fact Table:** `fact_family_indicator_snapshot` - Grain: one row per family, per indicator, per snapshot
- **Dimensions:** `dim_date`, `dim_family`, `dim_indicator`, `dim_organization`, `dim_survey_definition`
- **Materialization:** Staging = views (fast, no storage), Marts = tables (query performance)
- **Schema Separation:** Staging models in `staging` schema, marts in `marts` schema
- **Detailed specifications:** See `data_model/schema_docs/SCHEMA_REFERENCE.md`

## Critical Business Logic & Data Patterns

**Timestamp Handling:**
- Most timestamps stored as bigint milliseconds
- Convert using: `TO_TIMESTAMP(field/1000)` for datetime operations

**Survey Progression:**
- `snapshot_number = 1` - Baseline survey (initial assessment)
- `snapshot_number > 1` - Follow-up surveys (subsequent assessments)
- `is_last = true` - Most recent survey for a family (for current status queries)
- **Data Reality:** Follow-up rates typically 0-9% (expect significant dropout)

**Stoplight Poverty Scoring:**
- Red (1) = Critical poverty
- Yellow (2) = Moderate poverty/vulnerability
- Green (3) = Non-poor
- NULL = Indicator skipped/not applicable
- **Aggregate Score:** `(green×3 + yellow×2 + red×1) / (total_indicators×3)`

**Privacy & Anonymization:**
- When `anonymous = true`, personal fields show 'ANON_DATA'
- Affected fields: `name`, `first_name`, `last_name`, `gender`
- Always check `anonymous` flag before displaying personal information

**Template-Instance Architecture:**
- `survey_stoplight_indicator` (346 records) - Master template catalog
- `survey_stoplight` (20,081+ records) - Survey-specific implementations
- Relationship: `survey_stoplight.survey_stoplight_indicator_id → survey_stoplight_indicator.id`
- Pattern: One template reused across many surveys with customization

**Organizational Hierarchy:**
- Applications → Organizations → Families (nested hierarchy)
- Organizations can exist without families (e.g., newly onboarded orgs)
- Use `is_last = true` snapshots to avoid double-counting families

## dbt Model Development

**Naming Conventions:**
- `stg_` - Staging models (e.g., `stg_snapshots`, `stg_families`)
- `int_` - Intermediate models (business logic transformations)
- `fct_` - Fact tables (events, transactions, measurements)
- `dim_` - Dimension tables (entities, lookups, categories)

**Model Configuration (in SQL files):**
```sql
{{ config(
    materialized="view",  -- or "table" for marts
    tags=["staging"]      -- or ["mart", "semantic_layer"]
) }}

with base_data as (
    select
        id,
        family_id,
        snapshot_date,
        is_last
    from {{ source('data_collect', 'snapshot') }}  -- Reference source table
)

select * from base_data
where is_last = true
```

**Materialization Strategy (configured in dbt_project.yml):**
- Staging models: `view` (fast builds, no storage cost, always fresh)
- Mart models: `table` (slower builds, faster queries, query performance)
- Use `incremental` for very large fact tables (not currently needed)

**Model References:**
```sql
-- Reference staging models
{{ ref('stg_snapshots') }}

-- Reference source tables
{{ source('data_collect', 'snapshot') }}

-- Source format: {{ source('schema_name', 'table_name') }}
```

**SQL Style:**
- Use CTEs for readability and logical separation
- Lowercase SQL keywords
- One column per line in SELECT statements
- Avoid SELECT * in final models (explicit columns only)

## Documentation & Testing

**schema.yml Structure:**
- Keep schema.yml files alongside model SQL files (in `staging/` or `marts/` directories)
- The YAML filename can be anything (`schema.yml`, `_models.yml`, etc.)
- The `name` field in YAML must exactly match the SQL filename (without .sql extension)
- One schema.yml file can document multiple models
- **Policy:** Keep documentation simple - focus on model descriptions and basic column info
- Add `data_tests` only if explicitly requested (avoid over-testing initially)

**Minimal Documentation Example:**
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

**Common Test Types:**
```yaml
# Built-in generic tests
data_tests:
  - not_null
  - unique
  - accepted_values:
      values: [1, 2, 3]
  - relationships:
      to: ref('stg_families')
      field: family_id
```

**Custom Tests:**
- Create SQL files in `tests/` directory for business logic validation
- Example: `tests/assert_baseline_surveys_exist.sql`
- Tests return rows that fail the assertion (0 rows = test passes)

## Database Access & Source Data

**Source Database:** Neon PostgreSQL (Project ID: `soft-brook-12834941`)

**Access via Neon MCP Tool (Recommended):**
```sql
-- Query tables directly
mcp__neon__run_sql(projectId: "soft-brook-12834941", query: "SELECT ...")

-- Inspect schema structure
mcp__neon__describe_table_schema(projectId: "soft-brook-12834941", schema: "data_collect", table: "snapshot")

-- List all tables in a schema
mcp__neon__get_database_tables(projectId: "soft-brook-12834941")
```

**IMPORTANT:** Never modify the source database. Use database access only to:
- Inspect table schemas and relationships
- Query data for analysis and model design
- Validate dbt model logic
- Test transformations before implementing in dbt

**Source Documentation:**
- `data_model/schema_docs/SCHEMA_REFERENCE.md` - Star schema specifications
- `data_model/raw_data_collect_docs/RAW_SCHEMA.md` - Source table documentation
- `data_model/schema_docs/BUSINESS_QUESTIONS_DOCS.md` - Business requirements

## Claude Code Skills

This project includes custom Claude Code skills for AI-assisted dbt development:

**Available Skills:**
- `dbt-model-builder` - Create staging models, fact tables, dimension tables, sources, and documentation
- `metricflow-builder` - Build semantic models, measures, dimensions, and metrics with MetricFlow

**Installation:**
```bash
# Skills are located in claude-skills/ directory
# See claude-skills/README.md for installation instructions
```

**When to Use:**
- Building new dbt models from scratch
- Creating schema.yml documentation
- Implementing MetricFlow semantic layer
- Following dbt best practices and patterns

These skills provide step-by-step guidance, templates, and best practices tailored to this project's architecture.