# Poverty Stoplight Data Build

dbt semantic layer for the Poverty Stoplight database, providing business-ready models for LightDash BI tool.

## Architecture

This project implements a progressive dbt semantic layer based on the data architecture document. It focuses on creating business-ready models that directly serve LightDash users with two foundational model sets: **Indicator Performance** and **Survey Activity**.

### Key Principles
- **Progressive Development**: Start simple, add complexity incrementally
- **Template-Level Aggregation**: Focus on indicator templates (346) rather than implementations (20,000+)
- **Direct Business Models**: Subject-based organization without unnecessary layers
- **Current State Focus**: Prioritize latest data with historical context available

## Prerequisites

- Python 3.8+
- uv package manager
- PostgreSQL database access to Poverty Stoplight database
- Environment variables for database connection

## Setup

1. **Clone and navigate to project:**
   ```bash
   cd psp-data-build
   ```

2. **Install dependencies:**
   ```bash
   uv sync
   ```

3. **Activate virtual environment:**
   ```bash
   source .venv/bin/activate
   ```

4. **Set up environment variables:**
   Create a `.env` file with your database connection details:
   ```bash
   export DBT_HOST="your-postgres-host"
   export DBT_USER="your-username"
   export DBT_PASSWORD="your-password"
   export DBT_PORT="5432"
   export DBT_DBNAME="your-database-name"
   export DBT_SCHEMA="dbt_dev"
   ```

5. **Test connection:**
   ```bash
   dbt debug
   ```

## Models

### Indicator Models (`models/indicators/`)
- **`indicator_catalog`** - Master list of indicator templates with metadata and usage statistics
  - Grain: One row per indicator template
  - Key metrics: implementations, organizations using, total responses
- **`indicator_usage`** - Track which organizations use which indicator templates
  - Grain: One row per indicator template per organization
  - Key metrics: surveys using indicator, families measured, activity status
- **`indicator_performance`** - Current performance metrics for each indicator template
  - Grain: One row per indicator template per organization
  - Key metrics: red/yellow/green percentages, average scores

### Survey Models (`models/surveys/`)
- **`survey_definitions_active`** - Currently active survey configurations by organization
  - Grain: One row per active survey definition
  - Key metrics: indicator counts, economic questions, usage stats
- **`survey_activity`** - Survey collection metrics aggregated by month
  - Grain: One row per organization per month
  - Key metrics: baseline vs follow-up surveys, completion rates
- **`survey_completion`** - Survey engagement and retention metrics
  - Grain: One row per organization
  - Key metrics: retention rates, survey frequency, engagement patterns

## Development Commands

**Compile models (check for syntax errors):**
```bash
dbt compile
```

**Run all models:**
```bash
dbt run
```

**Run specific model:**
```bash
dbt run --select indicator_catalog
```

**Run models by tag:**
```bash
dbt run --select tag:working    # Only validated models
dbt run --select tag:staging    # In-development models
dbt run --select tag:indicators # Indicator models only
dbt run --select tag:surveys    # Survey models only
```

**Test models:**
```bash
dbt test
```

**Generate documentation:**
```bash
dbt docs generate
dbt docs serve
```

**Check for freshness:**
```bash
dbt source freshness
```

## Data Quality

The project includes comprehensive data quality tests:
- **Not null** tests on primary keys
- **Unique** tests on primary keys
- **Relationship** tests for foreign keys
- **Accepted values** tests for categorical fields
- **Custom** business logic tests

## Project Structure

```
dbt/
├── models/
│   ├── _sources.yml          # Source table definitions
│   ├── working/              # Validated, working models
│   │   ├── schema.yml
│   │   └── indicator_catalog_simple.sql
│   └── staging/              # In-development models
│       ├── schema.yml
│       ├── indicators/
│       │   ├── indicator_catalog.sql
│       │   ├── indicator_usage.sql
│       │   └── indicator_performance.sql
│       └── surveys/
│           ├── survey_definitions_active.sql
│           ├── survey_activity.sql
│           └── survey_completion.sql
├── dbt_project.yml           # Project configuration
└── README.md
```

## Database Connection

The project connects to the Poverty Stoplight PostgreSQL database with the following schemas:
- `data_collect` - Survey definitions, responses, and snapshots
- `ps_families` - Family master data
- `ps_network` - Organization and application data
- `ps_solutions` - Solutions data (future use)
- `library` - Library data (future use)

## Next Steps

After successful implementation, consider expanding with:
1. **Family Journey Models** - Individual family tracking
2. **Solution Effectiveness Models** - Impact analysis
3. **Geographic Analytics Models** - Regional comparisons
4. **Predictive Models** - Risk indicators and recommendations

## Contributing

1. Follow the established naming conventions
2. Add appropriate tests for new models
3. Update documentation for any schema changes
4. Test models against the database before committing

For detailed specifications, see `data_architecture.md`.