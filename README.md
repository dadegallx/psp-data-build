# Data Build Tool (dbt) Project

This repository contains a dbt (data build tool) project for creating a semantic data layer from your PostgreSQL database. dbt is a transformation framework that enables data teams to transform raw data in their warehouse by simply writing select statements, turning them into a reliable and documented data pipeline.

## What is dbt?

dbt (data build tool) is an open-source command-line tool that enables data analysts and engineers to transform data in their warehouse by writing simple SQL select statements. dbt handles the complexity of:

- **Dependencies**: Automatically builds models in the correct order
- **Testing**: Validates data quality with built-in and custom tests
- **Documentation**: Generates comprehensive documentation from your code
- **Version Control**: Integrates with Git for collaborative development
- **Incremental Processing**: Processes only new or changed data when appropriate

Think of dbt as "software engineering best practices for data transformations."

## Project Structure

```
├── dbt/                          # dbt project directory
│   ├── models/                   # SQL transformation models
│   │   ├── _sources.yml         # Source table definitions
│   │   ├── staging/             # Raw data cleaning models
│   │   └── marts/               # Business-ready analytical models
│   ├── tests/                   # Custom data quality tests
│   ├── dbt_project.yml         # Project configuration
│   └── profiles.yml             # Database connection settings
├── scripts/                     # Deployment and utility scripts
├── .env                        # Environment variables (not in git)
├── .env.template               # Template for required variables
└── pyproject.toml              # Python dependencies
```

## Local Development Setup

### Prerequisites

- **Python 3.8+**
- **uv package manager** (preferred over pip)
- **PostgreSQL database access**
- **Git** (for version control)

### Installation Steps

1. **Clone and navigate to the project:**
   ```bash
   git clone <repository-url>
   cd <project-directory>
   ```

2. **Install Python dependencies:**
   ```bash
   uv sync
   ```

3. **Activate the virtual environment:**
   ```bash
   source .venv/bin/activate
   ```

4. **Configure database connection:**

   Copy the template and fill in your database credentials:
   ```bash
   cp .env.template .env
   ```

   Edit `.env` with your PostgreSQL connection details:
   ```bash
   export DBT_HOST="your-postgres-host"
   export DBT_USER="your-username"
   export DBT_PASSWORD="your-password"
   export DBT_PORT="5432"
   export DBT_DBNAME="your-database-name"
   export DBT_SCHEMA="dbt_dev"  # Your development schema
   ```

5. **Test the database connection:**
   ```bash
   cd dbt
   source ../.env && dbt debug
   ```

### Essential dbt Commands

**Development workflow:**
```bash
# Check for syntax errors without running
dbt compile

# Run all models
dbt run

# Run specific model
dbt run --select model_name

# Run models by tag
dbt run --select tag:staging

# Test data quality
dbt test

# Generate and serve documentation
dbt docs generate && dbt docs serve
```

**Understanding the models:**

Your DBT project organizes SQL transformations as models, typically in a structure like:

```
models/
├── staging/      # Clean and standardize raw data
├── intermediate/ # Business logic transformations  
└── marts/        # Final analysis-ready tables
```

## Production Deployment

DBT is not like a real-time system that automatically updates when source data changes. Instead, it's a batch transformation tool that runs when you execute it.

### Orchestration and Scheduling
Since DBT runs on-demand, you'll need something to trigger it regularly. Popular approaches include:

**AWS-native options:**

- AWS EventBridge: Schedule DBT runs like a cron job
- AWS Step Functions: Orchestrate complex data pipelines
- Amazon ECS Scheduled Tasks: Run DBT in containers on schedule

**Third-party orchestrators:**

- Apache Airflow: Popular open-source option
- Prefect or Dagster: Modern Python-based alternatives
- DBT Cloud: Managed service that handles scheduling for you

The frequency depends on your data freshness requirements.

## Data Quality & Testing

This project includes comprehensive data quality tests:

- **Schema tests**: Not null, unique, relationships, accepted values
- **Custom tests**: Business logic validation
- **Source freshness**: Monitor data pipeline health

Run tests regularly:
```bash
dbt test                    # Run all tests
dbt test --select model_name  # Test specific model
```

## Documentation

Generate and view project documentation:
```bash
dbt docs generate
dbt docs serve  # Opens at http://localhost:8080
```

The documentation includes:
- Model descriptions and column definitions
- Data lineage graphs showing model dependencies
- Source data profiling and statistics
- Test results and data quality metrics

## Next Steps

After successful setup:

1. **Explore the models** using `dbt docs serve`
2. **Run initial transformations** with `dbt run`
3. **Connect your BI tool** to the transformed data tables (Basecamp!)
4. **Set up production deployment** consider using a dedicated PostgreSQL schema for dbt models (e.g., `analytics`)