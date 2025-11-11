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
├── data_model/                   # Data warehouse design documentation
│   ├── SCHEMA_REFERENCE.md      # Star schema specifications
│   └── BUSINESS_QUESTIONS_DOCS.md  # Business questions and metrics
├── dbt/                          # dbt project directory
│   ├── models/                   # SQL transformation models
│   │   ├── _sources.yml         # Source table definitions
│   │   ├── staging/             # Raw data cleaning models
│   │   ├── intermediate/        # Business logic transformations
│   │   ├── marts/               # Business-ready analytical models
│   │   └── semantic/            # MetricFlow semantic layer (future)
│   ├── tests/                   # Custom data quality tests
│   ├── dbt_project.yml         # Project configuration
│   └── profiles.yml             # Database connection settings
├── claude-skills/               # Claude Code AI skills for development
├── .claude/
│   └── CLAUDE.md               # Claude Code project guidance
├── .env                        # Environment variables (not in git)
├── .env.template               # Template for required variables
└── pyproject.toml              # Python dependencies
```

## Claude Skills for AI-Assisted Development

This project includes custom Claude Code skills to accelerate dbt development:

### Available Skills

**📦 dbt-model-builder**: Core dbt workflows for creating models, sources, tests, and documentation
**📊 metricflow-builder**: Semantic layer development with dbt's MetricFlow

### Quick Start

If you're using Claude Code, install the skills to get AI-powered assistance:

```bash
# Skills are located in the claude-skills/ directory
# See claude-skills/README.md for installation instructions
```

The skills provide:
- Step-by-step guidance for dbt development tasks
- Templates for staging, fact, and dimension models
- Best practices for testing and documentation
- MetricFlow semantic model and metrics patterns

**→ See [claude-skills/README.md](claude-skills/README.md) for full installation and usage guide**

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

dbt is a batch transformation tool that runs on-demand. For production, dbt runs can be scheduled using orchestration tools like AWS EventBridge, Apache Airflow, or dbt Cloud. The frequency depends on your data freshness requirements.

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

1. **Review the data model** - See `data_model/schema_docs/SCHEMA_REFERENCE.md` for schema design
2. **Explore business requirements** - Review `data_model/schema_docs/BUSINESS_QUESTIONS_DOCS.md`
3. **Install Claude skills** (optional) - See `claude-skills/README.md` for AI assistance
4. **View documentation** - Run `dbt docs serve` to explore the project
5. **Run transformations** - Execute `dbt run` to build models
6. **Connect your BI tool** to the transformed data tables