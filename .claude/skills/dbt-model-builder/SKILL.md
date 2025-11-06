---
name: dbt-model-builder
description: Create and manage dbt models for data transformation projects. Use this skill when building staging models from source tables, creating mart models (facts and dimensions), defining sources, writing schema documentation with tests, or generating dbt documentation. Covers dbt SQL best practices, YAML configuration, and common transformation patterns.
---

# dbt Model Builder

## Overview

Build data transformation models using dbt (data build tool). This skill provides guidance for creating staging models, mart models (facts and dimensions), defining sources, adding data quality tests, and generating documentation. Use this skill whenever working with dbt model development, schema definitions, or data transformation workflows.

## Core Capabilities

### 1. Define Sources in _sources.yml

Before building models, define source tables that dbt will read from.

**Create `models/_sources.yml`:**

```yaml
version: 2

sources:
  - name: data_collect
    description: "Survey data collection tables"
    database: postgres_db
    schema: data_collect
    tables:
      - name: snapshot
        description: "Survey snapshot records capturing family assessments"
        columns:
          - name: id
            description: "Primary key"
          - name: family_id
            description: "Foreign key to family table"
          - name: snapshot_date
            description: "Date of survey completion"
          - name: is_last
            description: "Flag indicating most recent survey for family"

      - name: snapshot_stoplight
        description: "Individual indicator assessments within snapshots"
        columns:
          - name: snapshot_id
            description: "Foreign key to snapshot table"
          - name: value
            description: "Stoplight value: 1=Red, 2=Yellow, 3=Green"

  - name: ps_families
    description: "Family master data"
    database: postgres_db
    schema: ps_families
    tables:
      - name: family
        description: "Family demographic and location information"
        columns:
          - name: family_id
            description: "Primary key"
          - name: code
            description: "Unique family code"
          - name: anonymous
            description: "Privacy flag for anonymized data"
```

**Best Practices:**
- Group tables by source schema
- Document all key columns (primary keys, foreign keys, business keys)
- Add descriptions that explain business meaning, not just technical details
- Use consistent naming conventions

### 2. Create Staging Models

Staging models clean and standardize raw source data. They apply minimal transformations: renaming, casting, basic filtering.

**Example: `models/staging/stg_snapshots.sql`**

```sql
{{
  config(
    materialized='view',
    tags=['staging', 'daily']
  )
}}

with source as (
    select * from {{ source('data_collect', 'snapshot') }}
),

renamed as (
    select
        -- Primary key
        id as snapshot_id,

        -- Foreign keys
        family_id,
        survey_definition_id,

        -- Attributes
        snapshot_number,
        is_last,
        to_timestamp(snapshot_date / 1000) as snapshot_date,
        to_timestamp(created_at / 1000) as created_at,
        to_timestamp(updated_at / 1000) as updated_at

    from source
)

select * from renamed
```

**Staging Model Patterns:**
- One staging model per source table
- Use `stg_` prefix for naming
- Materialize as views (lightweight, no storage)
- Apply column renaming and type casting
- Convert timestamps from milliseconds if needed
- Add meaningful comments for complex logic
- Use CTEs for readability: `source` → `renamed` → `final`

### 3. Create Fact Models

Fact models contain measurable events or transactions at atomic grain.

**Example: `models/marts/fct_family_indicator_snapshot.sql`**

```sql
{{
  config(
    materialized='table',
    tags=['mart', 'fact', 'core']
  )
}}

with snapshots as (
    select * from {{ ref('stg_snapshots') }}
),

stoplight_values as (
    select * from {{ ref('stg_snapshot_stoplight') }}
),

families as (
    select * from {{ ref('dim_family') }}
),

indicators as (
    select * from {{ ref('dim_indicator') }}
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key([
            'snapshots.snapshot_id',
            'indicators.indicator_key'
        ]) }} as family_indicator_snapshot_key,

        -- Foreign keys to dimensions
        to_char(snapshots.snapshot_date, 'YYYYMMDD')::integer as date_key,
        families.family_key,
        indicators.indicator_key,
        organizations.organization_key,
        survey_definitions.survey_definition_key,

        -- Degenerate dimensions
        snapshots.snapshot_id,
        snapshots.snapshot_number,
        snapshots.is_last,

        -- Measures
        stoplight_values.value as indicator_status_value

    from snapshots
    inner join families on snapshots.family_id = families.family_id
    inner join stoplight_values on snapshots.snapshot_id = stoplight_values.snapshot_id
    inner join indicators on stoplight_values.indicator_id = indicators.indicator_id
    -- Add other dimension joins as needed

    where snapshots.snapshot_date is not null
)

select * from final
```

**Fact Model Patterns:**
- Use `fct_` prefix for naming
- Materialize as tables for performance
- Define clear grain in model documentation
- Include surrogate keys for fact tables
- Add all relevant foreign keys to dimensions
- Include degenerate dimensions (non-dimensional attributes)
- Add measures (numeric/quantitative fields)
- Consider partitioning for very large tables

### 4. Create Dimension Models

Dimension models provide descriptive context for facts.

**Example: `models/marts/dim_family.sql`**

```sql
{{
  config(
    materialized='table',
    tags=['mart', 'dimension', 'core']
  )
}}

with families as (
    select * from {{ ref('stg_families') }}
),

family_members as (
    select * from {{ ref('stg_family_members') }}
),

-- Get country from first family member
family_countries as (
    select
        family_id,
        first_value(birth_country) over (
            partition by family_id
            order by created_at
        ) as country_code
    from family_members
    where birth_country is not null
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['families.family_id']) }} as family_key,

        -- Natural key
        families.family_id,

        -- Attributes
        families.code as family_code,
        case
            when families.anonymous then 'ANON_DATA'
            else families.name
        end as family_name,
        families.is_active as family_is_active,
        families.anonymous as is_anonymous,

        -- Geographic attributes
        family_countries.country_code,
        families.latitude::decimal(10,7) as latitude,
        families.longitude::decimal(10,7) as longitude,
        families.address,
        families.post_code,

        -- Audit fields
        families.created_at,
        families.updated_at

    from families
    left join family_countries using (family_id)
)

select * from final
```

**Dimension Model Patterns:**
- Use `dim_` prefix for naming
- Materialize as tables
- Include surrogate keys and natural keys
- Add descriptive attributes
- Handle slowly changing dimensions if needed (SCD Type 1/2)
- Apply privacy rules (anonymization logic)
- Consider hierarchy flattening for parent-child relationships

### 5. Add Schema Documentation and Tests

Document all models with schema files alongside the SQL.

**Example: `models/marts/schema.yml`**

```yaml
version: 2

models:
  - name: fct_family_indicator_snapshot
    description: >
      Captures poverty indicator assessments at atomic grain.
      One row per family, per indicator, per snapshot (survey completion).
      Estimated 225,000 current rows, growing by ~75K per 1,000 new families.
    columns:
      - name: family_indicator_snapshot_key
        description: "Surrogate key for this fact record"
        data_tests:
          - unique
          - not_null

      - name: date_key
        description: "Survey date key in YYYYMMDD format"
        data_tests:
          - not_null
          - relationships:
              to: ref('dim_date')
              field: date_key

      - name: family_key
        description: "Foreign key to family dimension"
        data_tests:
          - not_null
          - relationships:
              to: ref('dim_family')
              field: family_key

      - name: indicator_status_value
        description: "Stoplight status: 1=Red, 2=Yellow, 3=Green, NULL=Skipped"
        data_tests:
          - accepted_values:
              values: [1, 2, 3]
              config:
                severity: warn
                where: "indicator_status_value is not null"

      - name: snapshot_number
        description: "Survey round: 1=baseline, 2=first follow-up, etc."
        data_tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: "> 0"

  - name: dim_family
    description: "Family identity and geographic information"
    columns:
      - name: family_key
        description: "Surrogate key"
        data_tests:
          - unique
          - not_null

      - name: family_id
        description: "Natural key from source system"
        data_tests:
          - unique
          - not_null

      - name: family_code
        description: "Unique family code"
        data_tests:
          - unique
          - not_null
```

**Testing Best Practices:**
- Add `unique` and `not_null` tests to all keys
- Add `relationships` tests for foreign keys
- Use `accepted_values` for categorical fields
- Use `dbt_utils.expression_is_true` for custom logic
- Set appropriate severity levels (error vs warn)
- Add `where` clauses to handle nulls appropriately

### 6. Update Existing Models

When modifying existing models:

1. **Read the current model first** to understand its logic
2. **Check dependencies** using `dbt ls --select +model_name+` to see upstream/downstream impacts
3. **Make incremental changes** rather than complete rewrites when possible
4. **Update tests** if column names or logic changes
5. **Update documentation** in schema.yml to reflect changes
6. **Test locally** with `dbt run --select model_name` before committing

**Common update patterns:**
- Adding new columns: Append to SELECT statement
- Changing join logic: Update CTE and document reasoning
- Renaming columns: Update throughout model and in schema.yml
- Adding filters: Add to WHERE clause with clear comments
- Optimizing performance: Add indexes or change materialization

### 7. Model Configuration

Configure models using `config()` blocks in SQL or `dbt_project.yml`.

**In-model configuration (recommended for model-specific settings):**

```sql
{{
  config(
    materialized='table',
    tags=['mart', 'daily', 'core'],
    schema='analytics',
    unique_key='family_key',
    post_hook=[
      "grant select on {{ this }} to role reporter"
    ]
  )
}}
```

**Project-level configuration (in dbt_project.yml):**

```yaml
models:
  my_project:
    staging:
      +materialized: view
      +tags: ["staging"]
    marts:
      +materialized: table
      +tags: ["mart"]
      facts:
        +tags: ["fact"]
      dimensions:
        +tags: ["dimension"]
```

**Common configurations:**
- `materialized`: view, table, ephemeral
- `tags`: For organizing and selecting model groups
- `schema`: Override default schema
- `unique_key`: For deduplication in incremental models
- `on_schema_change`: fail, sync_all_columns, append_new_columns
- `pre_hook` / `post_hook`: SQL to run before/after model

### 8. Create Custom Macros

Macros are reusable Jinja functions for common logic patterns.

**Example: `macros/generate_schema_name.sql`**

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

**Example: `macros/cents_to_dollars.sql`**

```sql
{% macro cents_to_dollars(column_name, decimal_places=2) %}
    round({{ column_name }} / 100.0, {{ decimal_places }})
{% endmacro %}
```

**Usage in model:**

```sql
select
    order_id,
    {{ cents_to_dollars('amount_cents') }} as amount_dollars
from {{ ref('stg_orders') }}
```

**Common macro patterns:**
- Custom schema naming logic
- Data type conversions
- Privacy/anonymization logic
- Standard calculations (e.g., scoring formulas)
- Grant statements for access control

### 9. Generate and Serve Documentation

dbt automatically generates comprehensive documentation from your project.

**Generate documentation:**

```bash
dbt docs generate
```

This creates:
- Model descriptions from schema.yml files
- Column-level documentation
- Data lineage graphs (DAG visualization)
- Source data documentation
- Test coverage reports

**Serve documentation locally:**

```bash
dbt docs serve
```

Opens browser at `http://localhost:8080` with interactive documentation including:
- Full data lineage graph showing model dependencies
- Searchable model and column catalog
- SQL code for each model
- Test results and data quality metrics
- Source freshness information

**Best practices:**
- Regenerate docs after significant changes
- Review lineage graph to verify dependencies
- Use docs to onboard new team members
- Share documentation link with stakeholders

## SQL Style Best Practices

**Use CTEs for readability:**

```sql
-- Good: Clear progression of logic
with source as (
    select * from {{ source('schema', 'table') }}
),

filtered as (
    select * from source
    where status = 'active'
),

final as (
    select
        id,
        name,
        created_at
    from filtered
)

select * from final
```

**Naming conventions:**
- Use `snake_case` for all identifiers
- Prefix models: `stg_`, `int_`, `fct_`, `dim_`
- Descriptive CTE names: `source`, `renamed`, `filtered`, `joined`, `final`
- Always end with `select * from final`

**Column organization:**
- Primary keys first
- Foreign keys second
- Attributes grouped logically
- Audit fields last (created_at, updated_at)

**Comments and readability:**
- Add comments for complex business logic
- Group related columns with blank lines
- Use consistent indentation (4 spaces)
- One column per line in SELECT statements

## Common Patterns

**Join pattern:**

```sql
with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('dim_customers') }}
),

final as (
    select
        orders.order_id,
        customers.customer_name,
        orders.order_amount
    from orders
    inner join customers using (customer_id)
)

select * from final
```

**Aggregation pattern:**

```sql
with base as (
    select * from {{ ref('fct_orders') }}
),

aggregated as (
    select
        customer_id,
        count(*) as order_count,
        sum(order_amount) as total_amount,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date
    from base
    where order_status = 'completed'
    group by 1
)

select * from aggregated
```

## Resources

### references/

Reference materials to inform dbt development:

- **schema_reference.md** - Data warehouse schema specifications for understanding table structures, relationships, and data patterns
- **dbt_best_practices.md** - Comprehensive SQL style guide, naming conventions, and transformation patterns

Load these references when you need detailed context about:
- Source table structures and relationships
- Data warehouse design patterns
- Advanced SQL patterns and conventions
- Complex transformation requirements

### assets/

Template files for quickly creating new dbt models:

- **staging_model_template.sql** - Template for creating staging models from source tables
- **fact_model_template.sql** - Template for creating fact table models
- **dimension_model_template.sql** - Template for creating dimension models
- **schema_template.yml** - Template for model documentation with tests
- **sources_template.yml** - Template for defining source tables
- **folder_structure.txt** - Reference guide for organizing dbt project directories

Use these templates as starting points. Customize column names, join logic, and business rules based on specific requirements.
