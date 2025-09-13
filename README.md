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

## Lightdash Deployment

This project is designed to work seamlessly with [Lightdash](https://www.lightdash.com/), an open-source BI tool that connects directly to your dbt models.

### Prerequisites for Lightdash

- Node.js 18+ (for Lightdash CLI)
- Local Lightdash instance running on Docker
- Valid database connection (`.env` file configured)

### Quick Deployment

**Automated deployment (recommended):**
```bash
./scripts/deploy-to-lightdash.sh
```

This script will:
- Check and install prerequisites (dbt, Lightdash CLI)
- Validate your database connection
- Deploy all models to Lightdash
- Provide deployment status and next steps

### Manual Deployment

If you prefer manual deployment:

1. **Install Lightdash CLI:**
   ```bash
   npm install -g @lightdash/cli@0.2001.1
   ```

2. **Install dbt (if not already installed):**
   ```bash
   uv tool install dbt-core --with dbt-postgres
   ```

3. **Login to Lightdash:**
   ```bash
   lightdash login http://localhost:8080 --token YOUR_TOKEN
   ```

4. **Navigate to dbt directory and deploy:**
   ```bash
   cd dbt
   source ../.env && lightdash deploy --create
   ```

### What Gets Deployed

- **Working models** (`tag:working`): Production-ready models like `indicator_catalog_simple`
- **Staging models** (`tag:staging`): Development models for testing and iteration
- **All column definitions** from `schema.yml` files become Lightdash dimensions
- **Data tests** are preserved and visible in Lightdash

### Using Lightdash

After deployment:
1. Visit http://localhost:8080 in your browser
2. Navigate to your project (default: "PSP Data Build")
3. Explore the available tables:
   - **indicator_catalog_simple**: Ready-to-use indicator catalog
   - **staging models**: For development and testing
4. Create charts, dashboards, and reports using the familiar drag-and-drop interface

### Troubleshooting

**Environment variable issues:**
- Ensure `.env` file is in the project root (not in the `dbt/` directory)
- Check that all required variables are set: `DBT_HOST`, `DBT_USER`, `DBT_PASSWORD`, `DBT_DBNAME`

**Node.js version warnings:**
- Lightdash CLI is optimized for Node.js v20
- Most functionality works on newer versions, but consider using Node v20 for best compatibility

**Database connection errors:**
- Test your connection: `cd dbt && source ../.env && dbt debug`
- Verify your database credentials and network access

**Model compilation issues:**
- Run `dbt compile` to check for syntax errors
- Ensure all source tables are accessible with your credentials

## Data Quality

The project includes comprehensive data quality tests:
- **Not null** tests on primary keys
- **Unique** tests on primary keys
- **Relationship** tests for foreign keys
- **Accepted values** tests for categorical fields
- **Custom** business logic tests

## Project Structure

```
psp-data-build/
├── dbt/                      # dbt project directory
│   ├── models/
│   │   ├── _sources.yml          # Source table definitions
│   │   ├── working/              # Validated, working models
│   │   │   ├── schema.yml
│   │   │   └── indicator_catalog_simple.sql
│   │   └── staging/              # In-development models
│   │       ├── schema.yml
│   │       ├── indicators/
│   │       │   ├── indicator_catalog.sql
│   │       │   ├── indicator_usage.sql
│   │       │   └── indicator_performance.sql
│   │       └── surveys/
│   │           ├── survey_definitions_active.sql
│   │           ├── survey_activity.sql
│   │           └── survey_completion.sql
│   ├── dbt_project.yml           # Project configuration
│   └── README.md
├── scripts/
│   └── deploy-to-lightdash.sh    # Automated deployment script
├── .env                          # Database connection credentials
├── .env.template                 # Template for environment variables
├── pyproject.toml               # Python dependencies
├── uv.lock                      # Lock file for dependencies
└── README.md                    # This file
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