---
name: metricflow-builder
description: Build semantic layer components using dbt's MetricFlow. Use this skill when defining semantic models, creating measures and dimensions, building metrics (simple, ratio, derived), setting up time spine models, or configuring the semantic layer for downstream BI tools. Covers MetricFlow YAML configuration, entity-based join logic, and CLI commands for testing metrics during development.
---

# MetricFlow Semantic Layer Builder

Use this skill to build dbt's semantic layer components using MetricFlow - the SQL generation engine that powers dbt's metric framework.

## Core Capabilities

### 1. Define Semantic Models

Semantic models are the foundation of MetricFlow, serving as nodes in a semantic graph that connect to your dbt models.

**File Location**: Store semantic models in `models/semantic_models/` directory with `sem_` prefix (e.g., `sem_orders.yml`)

**Basic Structure**:

```yaml
semantic_models:
  - name: orders_semantic_model
    description: >
      Core order events with customer and product relationships.
      Grain: One row per order.
    model: ref('fct_orders')

    defaults:
      agg_time_dimension: order_date

    entities:
      - name: order
        type: primary
        expr: order_id
      - name: customer
        type: foreign
        expr: customer_id
      - name: product
        type: foreign
        expr: product_id

    dimensions:
      - name: order_date
        type: time
        type_params:
          time_granularity: day
      - name: order_status
        type: categorical
      - name: order_region
        type: categorical
        expr: region

    measures:
      - name: order_count
        agg: count
        expr: order_id
      - name: total_revenue
        agg: sum
        expr: order_amount
      - name: avg_order_value
        agg: average
        expr: order_amount
```

**Key Points**:
- `name`: Unique identifier for the semantic model
- `model`: Reference to underlying dbt model using `ref()`
- `defaults.agg_time_dimension`: Primary time dimension for the model
- Must include at least one primary entity and one time dimension if measures are present

---

### 2. Define Entities

Entities serve as join keys that enable MetricFlow to automatically join semantic models together.

**Four Entity Types**:

**Primary**: One record per row, complete dataset coverage (cannot be null)
```yaml
entities:
  - name: transaction
    type: primary
    expr: transaction_id
```

**Unique**: One record per row, may contain subset (allows nulls)
```yaml
entities:
  - name: user_account
    type: unique
    expr: account_id
```

**Foreign**: Links to other tables (allows multiple instances and nulls)
```yaml
entities:
  - name: customer
    type: foreign
    expr: customer_id
  - name: product
    type: foreign
    expr: product_id
```

**Natural**: Used exclusively with SCD Type II dimensions (not commonly used)

**Best Practices**:
- Use singular names (`customer` not `customer_id`)
- Every semantic model needs one primary entity
- Foreign entities enable cross-model joins
- Use `expr` to reference the actual column name if different from entity name

---

### 3. Define Dimensions

Dimensions are non-aggregatable attributes used for grouping and filtering data.

**Categorical Dimensions**:
```yaml
dimensions:
  - name: product_category
    type: categorical
    description: "Product classification (electronics, clothing, etc.)"

  - name: customer_tier
    type: categorical
    expr: >
      case
        when lifetime_value > 10000 then 'Premium'
        when lifetime_value > 1000 then 'Standard'
        else 'Basic'
      end
```

**Time Dimensions**:
```yaml
dimensions:
  - name: order_date
    type: time
    type_params:
      time_granularity: day
    description: "Date when order was placed"

  - name: created_at
    type: time
    type_params:
      time_granularity: hour
```

**Available Time Granularities**: `second`, `minute`, `hour`, `day`, `week`, `month`, `quarter`, `year`

**Best Practices**:
- Include at least one time dimension for any semantic model with measures
- Use `expr` to create computed dimensions without changing underlying model
- Document dimensions clearly for downstream users

---

### 4. Define Measures

Measures are aggregations that serve as building blocks for metrics.

**Supported Aggregation Types**:

```yaml
measures:
  # Count
  - name: transaction_count
    agg: count
    expr: transaction_id

  # Sum
  - name: total_revenue
    agg: sum
    expr: revenue_amount

  # Average
  - name: avg_order_size
    agg: average
    expr: order_quantity

  # Min/Max
  - name: min_price
    agg: min
    expr: unit_price

  - name: max_price
    agg: max
    expr: unit_price

  # Count Distinct
  - name: unique_customers
    agg: count_distinct
    expr: customer_id

  # Median
  - name: median_order_value
    agg: median
    expr: order_amount

  # Percentile (requires agg_params)
  - name: p95_response_time
    agg: percentile
    expr: response_time_ms
    agg_params:
      percentile: 0.95
      use_discrete_percentile: true

  # Sum Boolean (counts true values)
  - name: returned_orders
    agg: sum_boolean
    expr: is_returned
```

**Best Practices**:
- Measures must have unique names across ALL semantic models
- Use descriptive names that indicate the aggregation (e.g., `total_revenue` not just `revenue`)
- Always include `description` for clarity
- Measures become reusable across multiple metrics

---

### 5. Create Metrics

Metrics are defined in YAML files within the `models/semantic_models/` directory.

#### 5.1 Simple Metrics

Simple metrics point directly to a measure with optional filters.

```yaml
metrics:
  - name: total_orders
    description: "Total count of all orders"
    type: simple
    label: Total Orders
    type_params:
      measure: order_count

  - name: completed_orders
    description: "Orders with completed status"
    type: simple
    label: Completed Orders
    type_params:
      measure: order_count
    filter: |
      {{ Dimension('order__order_status') }} = 'completed'
```

#### 5.2 Ratio Metrics

Ratio metrics compare a numerator to a denominator metric.

```yaml
metrics:
  - name: return_rate
    description: "Percentage of orders that were returned"
    type: ratio
    label: Return Rate
    type_params:
      numerator: returned_orders
      denominator: total_orders

  - name: premium_revenue_share
    description: "Percentage of revenue from premium customers"
    type: ratio
    label: Premium Revenue %
    type_params:
      numerator:
        name: premium_revenue
        filter: |
          {{ Dimension('customer__tier') }} = 'Premium'
      denominator: total_revenue
```

**Best Practices**:
- Numerator and denominator can have independent filters
- Use for percentage calculations, rates, and proportions
- Label should indicate the ratio nature (e.g., "Rate", "%", "Per")

#### 5.3 Derived Metrics

Derived metrics combine multiple metrics using mathematical expressions.

```yaml
metrics:
  - name: revenue_per_customer
    description: "Average revenue generated per unique customer"
    type: derived
    label: Revenue per Customer
    type_params:
      expr: total_revenue / unique_customers
      metrics:
        - name: total_revenue
        - name: unique_customers

  - name: month_over_month_growth
    description: "MoM revenue growth rate"
    type: derived
    label: MoM Growth %
    type_params:
      expr: (current_month_revenue - prior_month_revenue) / prior_month_revenue * 100
      metrics:
        - name: current_month_revenue
          alias: current_month_revenue
        - name: total_revenue
          alias: prior_month_revenue
          offset_window: 1 month
```

**Best Practices**:
- List all component metrics in `metrics` array
- Use `alias` for clarity in expressions
- Use `offset_window` for time-based comparisons
- Supports complex calculations without hardcoding logic in models

---

### 6. Set Up Time Spine Model

Time spine is required for time-based metric calculations and date range queries.

#### 6.1 Create Time Spine SQL Model

**File**: `models/semantic_models/metricflow_time_spine.sql`

```sql
{{
  config(
    materialized='table',
    tags=['semantic_layer', 'time_spine']
  )
}}

-- Daily granularity time spine
with date_spine as (
    {{ dbt.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="cast(current_date + interval '1 year' as date)"
    ) }}
)

select
    date_day,
    date_trunc('week', date_day) as date_week,
    date_trunc('month', date_day) as date_month,
    date_trunc('quarter', date_day) as date_quarter,
    date_trunc('year', date_day) as date_year
from date_spine
```

#### 6.2 Configure Time Spine Semantic Model

**File**: `models/semantic_models/sem_metricflow_time_spine.yml`

```yaml
semantic_models:
  - name: metricflow_time_spine
    description: "Date dimension for time-based metric calculations"
    model: ref('metricflow_time_spine')

    defaults:
      agg_time_dimension: date_day

    primary_entity: date_day

    dimensions:
      - name: date_day
        type: time
        label: Date (Daily)
        type_params:
          time_granularity: day
          is_primary: true

      - name: date_week
        type: time
        label: Date (Weekly)
        type_params:
          time_granularity: week

      - name: date_month
        type: time
        label: Date (Monthly)
        type_params:
          time_granularity: month
```

**Granularity Options**:
- **Daily**: Most common, good for most use cases
- **Weekly**: For weekly reporting (requires `date_week` column)
- **Monthly**: For monthly aggregations (requires `date_month` column)

**Best Practices**:
- Set `start_date` to earliest data date
- Set `end_date` to extend beyond current date (e.g., +1 year)
- Include all granularities you'll need for metrics
- Only one time spine model needed per project

---

### 7. File Organization (Dedicated Subfolder)

Use dedicated `models/semantic_models/` directory structure:

```
models/
├── marts/
│   ├── core/
│   │   ├── fct_orders.sql
│   │   └── dim_customers.sql
│   └── finance/
│       └── fct_transactions.sql
└── semantic_models/
    ├── _semantic_models.yml       # All semantic model definitions
    ├── _metrics.yml                # All metric definitions
    ├── metricflow_time_spine.sql   # Time spine model
    └── sem_metricflow_time_spine.yml
```

**Alternative: One file per mart**
```
models/
└── semantic_models/
    ├── sem_orders.yml        # Semantic model + metrics for orders
    ├── sem_customers.yml     # Semantic model + metrics for customers
    ├── sem_transactions.yml
    ├── metricflow_time_spine.sql
    └── sem_metricflow_time_spine.yml
```

**Naming Convention**:
- Prefix semantic model files with `sem_` (e.g., `sem_orders.yml`)
- Keeps semantic files distinct from regular model YAML files
- Store all semantic assets in `models/semantic_models/` directory

---

### 8. Test and Query Metrics (CLI Commands)

Use MetricFlow CLI during development to test and validate metrics.

**List Available Metrics**:
```bash
dbt sl list metrics
dbt sl list metrics --search revenue  # Filter by keyword
```

**Show Metric Dimensions**:
```bash
dbt sl list dimensions --metrics total_revenue
```

**Query Metrics**:
```bash
# Basic query
dbt sl query --metrics total_revenue --group-by order_date

# With filters
dbt sl query \
  --metrics total_revenue,order_count \
  --group-by order_date,order_region \
  --where "order_status = 'completed'"

# Time range
dbt sl query \
  --metrics total_revenue \
  --group-by order_date \
  --start-time 2024-01-01 \
  --end-time 2024-12-31

# Order and limit
dbt sl query \
  --metrics total_revenue \
  --group-by order_region \
  --order-by -total_revenue \
  --limit 10

# View generated SQL
dbt sl query \
  --metrics total_revenue \
  --group-by order_date \
  --compile
```

**Validate Configuration**:
```bash
dbt sl validate  # Validates all semantic models and metrics
dbt parse        # Refresh semantic manifest after changes
```

**List Other Components**:
```bash
dbt sl list entities --metrics total_revenue
dbt sl list dimension-values --metrics total_revenue --dimension order_status
```

**Common Workflow**:
1. Make changes to semantic model or metric YAML
2. Run `dbt parse` to refresh manifest
3. Run `dbt sl validate` to check configuration
4. Run `dbt sl query` to test metric calculations
5. Use `--compile` to inspect generated SQL
6. Deploy when satisfied with results

---

## MetricFlow Best Practices

### Naming Conventions
- **Entities**: Use singular names (`customer`, `order`, `product`)
- **Dimensions**: Use descriptive names without prefixes (`order_date`, `product_category`)
- **Measures**: Include aggregation type in name (`total_revenue`, `avg_order_value`, `unique_customers`)
- **Metrics**: Use business-friendly names (`return_rate`, `revenue_per_customer`)

### Semantic Model Design
- Start with one semantic model per fact table
- Include one primary entity representing the grain
- Add foreign entities for relationships to other tables
- Always include a primary time dimension for models with measures
- Document the grain clearly in the description

### Measure Strategy
- Create measures as distinct components (don't nest them in metrics)
- Use simple, focused measures that can be reused
- Measures are the building blocks - keep them atomic
- Use descriptive names that indicate aggregation type

### Metric Development
- Start with simple metrics before building complex ones
- Use ratio metrics for percentages and rates
- Use derived metrics for calculations across multiple metrics
- Avoid hardcoding business logic in underlying dbt models - define it in metrics
- Always include clear descriptions and labels

### Join Logic
- MetricFlow uses entities as automatic join keys
- Matching entity names across semantic models enable joins
- Query dimensions from other models using `entity__dimension` syntax
- MetricFlow prevents problematic fan-out joins automatically

### Testing and Validation
- Use `dbt sl validate` to catch configuration errors early
- Test metrics with `dbt sl query` during development
- Use `--compile` flag to inspect generated SQL
- Verify results match expected business logic before deploying

### Documentation
- Document semantic models with clear grain statements
- Add descriptions to all entities, dimensions, and measures
- Explain metric business logic in descriptions
- Use labels for user-friendly display names in BI tools

---

## Key Concepts Reference

### Entity-Based Joins
- MetricFlow automatically joins semantic models using matching entity names
- No manual join logic required - define entities and MetricFlow handles the rest
- Supports up to 2-hop joins across 3 tables
- Use `entity__dimension` syntax to access joined dimensions

### Time Dimensions
- Every semantic model with measures should have a primary time dimension
- Set via `defaults.agg_time_dimension` in semantic model config
- Required for time-based filtering and grouping
- Time spine model enables date range queries

### Semantic Graph
- Network of semantic models connected by entities
- Enables flexible metric querying across related data
- MetricFlow traverses graph to generate optimal SQL
- Validates join paths before execution

### DRY Principle
- Define metrics once, use everywhere
- Measures are reusable across multiple metrics
- Metrics can be composed into derived metrics
- Eliminates duplicated business logic across reports

---

## Resources

Refer to the following resources for additional guidance:

**Project References**:
- `references/metricflow_best_practices.md` - Comprehensive MetricFlow patterns and standards
- `references/schema_reference.md` - Data warehouse schema for context
- `references/business_questions_docs.md` - Business questions and metrics to model

**Templates** (in `assets/`):
- `semantic_model_template.yml` - Generic semantic model structure
- `metrics_template.yml` - Templates for simple, ratio, and derived metrics
- `time_spine_model_template.sql` - Time spine model with multiple granularities
- `folder_structure.txt` - Recommended file organization

**Official Documentation**:
- dbt Docs: https://docs.getdbt.com/docs/build/about-metricflow
- MetricFlow CLI: https://docs.getdbt.com/docs/build/metricflow-commands
