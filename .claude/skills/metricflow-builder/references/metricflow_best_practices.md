# MetricFlow Best Practices & Patterns

## Overview

This guide provides comprehensive patterns and standards for building semantic models and metrics with dbt's MetricFlow. These practices ensure consistency, maintainability, and optimal performance.

---

## Semantic Model Design Patterns

### Start with Fact Tables

Build semantic models primarily from fact tables (event-based or transactional data).

**Pattern:**
```yaml
semantic_models:
  - name: orders
    model: ref('fct_orders')  # Fact table
    description: >
      Core order events.
      Grain: One row per order.
```

**Why:** Fact tables contain the measures (metrics building blocks) and events you want to analyze.

---

### Document the Grain Clearly

Always state the grain (one row per...) in the semantic model description.

**Pattern:**
```yaml
semantic_models:
  - name: order_lines
    description: >
      Individual line items within orders.
      Grain: One row per order line item.
      Business logic: Captures product-level detail for order analysis.
```

**Why:** Clear grain documentation prevents misunderstandings about aggregation levels and helps users choose the right semantic model.

---

### One Primary Entity Required

Every semantic model must have exactly one primary entity representing its grain.

**Pattern:**
```yaml
entities:
  - name: order  # Primary entity
    type: primary
    expr: order_id

  - name: customer  # Foreign entity for joins
    type: foreign
    expr: customer_id
```

**Why:** The primary entity defines uniqueness and enables MetricFlow to prevent invalid aggregations.

---

### Foreign Entities Enable Joins

Add foreign entities to enable cross-model querying without manual joins.

**Pattern:**
```yaml
# In orders semantic model
entities:
  - name: customer
    type: foreign
    expr: customer_id

  - name: product
    type: foreign
    expr: product_id

# MetricFlow can now automatically join to customer and product dimensions
```

**Why:** Matching entity names across semantic models enable automatic join logic.

---

## Dimension Best Practices

### Include Primary Time Dimension

Every semantic model with measures should have a primary time dimension.

**Pattern:**
```yaml
defaults:
  agg_time_dimension: order_date

dimensions:
  - name: order_date
    type: time
    type_params:
      time_granularity: day
```

**Why:** Required for time-based filtering, grouping, and period-over-period comparisons.

---

### Use Computed Dimensions

Create computed dimensions using `expr` without modifying underlying dbt models.

**Pattern:**
```yaml
dimensions:
  - name: customer_segment
    type: categorical
    expr: >
      case
        when total_orders > 10 then 'Frequent'
        when total_orders > 3 then 'Regular'
        else 'Occasional'
      end
```

**Why:** Keeps transformation logic centralized in the semantic layer, following DRY principles.

---

### Time Granularity Selection

Choose appropriate time granularity based on data refresh frequency and analysis needs.

**Pattern:**
```yaml
# Transactional data - hour or day
- name: transaction_timestamp
  type: time
  type_params:
    time_granularity: hour

# Daily summary data
- name: report_date
  type: time
  type_params:
    time_granularity: day

# Monthly aggregations
- name: month_date
  type: time
  type_params:
    time_granularity: month
```

**Why:** Matches granularity to data structure and prevents inappropriate aggregations.

---

## Measure Design Patterns

### Descriptive Naming with Aggregation Type

Include the aggregation type in measure names for clarity.

**Pattern:**
```yaml
measures:
  - name: total_revenue      # sum
  - name: avg_order_value    # average
  - name: order_count        # count
  - name: unique_customers   # count_distinct
  - name: max_order_amount   # max
```

**Why:** Makes the measure's purpose immediately clear to metric developers and consumers.

---

### Atomic Measures

Keep measures simple and focused - they're building blocks for metrics.

**Good Pattern:**
```yaml
measures:
  - name: order_count
    agg: count
    expr: order_id

  - name: total_revenue
    agg: sum
    expr: order_amount
```

**Anti-Pattern:**
```yaml
# DON'T create complex measures
measures:
  - name: revenue_per_customer  # This should be a derived metric!
    agg: average  # Confusing aggregation
    expr: order_amount / customer_count  # Complex logic
```

**Why:** Complex logic belongs in derived metrics, not measures.

---

### Sum Boolean for Conditional Counts

Use `sum_boolean` aggregation to count records matching conditions.

**Pattern:**
```yaml
measures:
  - name: returned_orders
    agg: sum_boolean
    expr: is_returned  # Boolean column

  - name: high_value_orders
    agg: sum_boolean
    expr: order_amount > 1000  # Boolean expression
```

**Why:** More efficient than `count` with complex filters.

---

## Metric Building Patterns

### Start Simple, Build Complex

Progress from simple to ratio to derived metrics.

**Development Flow:**
```yaml
# Step 1: Simple metrics (direct measures)
- name: total_revenue
  type: simple
  type_params:
    measure: total_revenue

- name: order_count
  type: simple
  type_params:
    measure: order_count

# Step 2: Ratio metrics (percentages, rates)
- name: avg_order_value
  type: ratio
  type_params:
    numerator: total_revenue
    denominator: order_count

# Step 3: Derived metrics (complex calculations)
- name: revenue_growth_rate
  type: derived
  type_params:
    expr: (current_revenue - prior_revenue) / prior_revenue
    metrics:
      - name: total_revenue
        alias: current_revenue
      - name: total_revenue
        alias: prior_revenue
        offset_window: 1 year
```

**Why:** Builds understanding progressively and reuses simpler metrics in complex ones.

---

### Ratio Metrics for Percentages

Use ratio metrics for all percentage and rate calculations.

**Pattern:**
```yaml
metrics:
  - name: conversion_rate
    description: "Percentage of visitors who complete a purchase"
    type: ratio
    label: Conversion Rate %
    type_params:
      numerator: purchase_count
      denominator: visitor_count

  - name: return_rate
    description: "Percentage of orders that were returned"
    type: ratio
    label: Return Rate %
    type_params:
      numerator: returned_orders
      denominator: total_orders
```

**Why:** Ratio metrics automatically handle division by zero and provide clean percentage semantics.

---

### Independent Filters in Ratios

Apply different filters to numerator and denominator when needed.

**Pattern:**
```yaml
metrics:
  - name: premium_revenue_share
    type: ratio
    label: Premium Revenue %
    type_params:
      numerator:
        name: total_revenue
        filter: |
          {{ Dimension('customer__tier') }} = 'Premium'
      denominator: total_revenue
```

**Why:** Enables sophisticated percentage calculations without creating separate metrics.

---

### Derived Metrics for Period Comparisons

Use `offset_window` in derived metrics for time-based comparisons.

**Pattern:**
```yaml
metrics:
  - name: month_over_month_growth
    description: "MoM revenue growth percentage"
    type: derived
    label: MoM Growth %
    type_params:
      expr: (current - prior) / prior * 100
      metrics:
        - name: total_revenue
          alias: current
        - name: total_revenue
          alias: prior
          offset_window: 1 month

  - name: year_over_year_change
    type: derived
    label: YoY Change
    type_params:
      expr: current - prior
      metrics:
        - name: total_revenue
          alias: current
        - name: total_revenue
          alias: prior
          offset_window: 1 year
```

**Why:** Avoids hardcoding period logic in SQL and enables flexible time comparisons.

---

## Filter Patterns

### Dimension Filters in Metrics

Apply filters using Jinja template syntax.

**Pattern:**
```yaml
metrics:
  - name: completed_orders
    type: simple
    type_params:
      measure: order_count
    filter: |
      {{ Dimension('order__status') }} = 'completed'

  - name: us_revenue
    type: simple
    type_params:
      measure: total_revenue
    filter: |
      {{ Dimension('customer__country') }} = 'US'

  - name: recent_orders
    type: simple
    type_params:
      measure: order_count
    filter: |
      {{ TimeDimension('order__order_date', 'day') }} >= '2024-01-01'
```

**Why:** Filters in metric definitions create reusable, named metrics for common business logic.

---

### Entity Prefixes for Disambiguation

Use entity prefixes when dimensions exist in multiple models.

**Pattern:**
```yaml
# If "location" exists in both orders and customers
filter: |
  {{ Dimension('customer__location') }} = 'New York'  # Customer location
  AND {{ Dimension('order__location') }} = 'New York'  # Order location
```

**Why:** Prevents ambiguity in joined queries.

---

## Time Spine Setup

### Comprehensive Granularities

Include all time granularities you'll need for analysis.

**Pattern:**
```sql
select
    date_day,
    date_trunc('week', date_day) as date_week,
    date_trunc('month', date_day) as date_month,
    date_trunc('quarter', date_day) as date_quarter,
    date_trunc('year', date_day) as date_year
from date_spine
```

**Why:** Enables flexible time-based analysis without regenerating the time spine.

---

### Extend Beyond Current Date

Set `end_date` to future date (typically +1 year).

**Pattern:**
```sql
{{ dbt.date_spine(
    datepart="day",
    start_date="cast('2020-01-01' as date)",
    end_date="cast(current_date + interval '1 year' as date)"
) }}
```

**Why:** Supports forecasting and future-dated queries.

---

## Entity Design Patterns

### Singular Entity Names

Use singular form for entity names, even if column is plural or has `_id` suffix.

**Pattern:**
```yaml
# Column: customer_id
entities:
  - name: customer  # Singular
    type: foreign
    expr: customer_id

# Column: order_ids (array)
entities:
  - name: order  # Still singular
    type: foreign
    expr: order_id
```

**Why:** Singular names are more intuitive when referencing entities in queries and filters.

---

### Consistent Entity Names Across Models

Use identical entity names across semantic models to enable automatic joins.

**Pattern:**
```yaml
# In orders semantic model
entities:
  - name: customer
    type: foreign
    expr: customer_id

# In customers semantic model
entities:
  - name: customer
    type: primary
    expr: customer_id

# MetricFlow automatically knows these can join!
```

**Why:** Name matching is how MetricFlow determines join paths.

---

## Testing and Validation

### Development Workflow

Follow this workflow for iterative development:

```bash
# 1. Make changes to semantic model or metrics
# 2. Refresh manifest
dbt parse

# 3. Validate configuration
dbt sl validate

# 4. Test metric calculation
dbt sl query --metrics my_metric --group-by dimension

# 5. Inspect generated SQL
dbt sl query --metrics my_metric --group-by dimension --compile

# 6. Iterate until satisfied
```

---

### Common Validation Checks

Validate these aspects before deploying:

**Configuration Validation:**
```bash
dbt sl validate  # Catches YAML syntax and semantic errors
```

**Measure Uniqueness:**
- Ensure measure names are unique across ALL semantic models
- MetricFlow will error if duplicate measure names exist

**Entity Relationships:**
- Verify foreign entities match primary entities in related models
- Check that entity names are consistent across models

**Dimension Types:**
- Time dimensions have `time_granularity` specified
- Categorical dimensions don't have time parameters

**Metric Calculations:**
- Query metrics with sample data to verify results
- Use `--compile` to inspect generated SQL
- Compare results to manual calculations

---

## Documentation Standards

### Semantic Model Documentation

Include grain, business logic, and refresh information.

**Pattern:**
```yaml
semantic_models:
  - name: orders
    description: >
      Core order events with customer and product relationships.

      Grain: One row per order.

      Refresh: Daily at 2am UTC via incremental model.

      Business logic:
      - Includes only completed orders (excludes cancelled)
      - Revenue is net of returns and discounts
      - Created_at represents order placement timestamp
```

---

### Measure Documentation

Explain what the measure represents and any important nuances.

**Pattern:**
```yaml
measures:
  - name: net_revenue
    agg: sum
    expr: order_amount - discount_amount - return_amount
    description: >
      Total revenue after discounts and returns.
      Represents actual cash received from customers.
```

---

### Metric Documentation

Explain business meaning, calculation logic, and use cases.

**Pattern:**
```yaml
metrics:
  - name: customer_lifetime_value
    description: >
      Average total revenue per customer over their entire relationship.

      Calculation: Total revenue / Unique customers

      Use cases:
      - Customer acquisition cost analysis
      - Customer segmentation
      - Marketing ROI evaluation
    type: derived
    label: Customer Lifetime Value
    type_params:
      expr: total_revenue / unique_customers
      metrics:
        - name: total_revenue
        - name: unique_customers
```

---

## File Organization Patterns

### Dedicated Subfolder (Recommended)

Keep semantic layer separate from regular models.

**Structure:**
```
models/
├── marts/
│   └── core/
│       ├── fct_orders.sql
│       └── fct_orders.yml
└── semantic_models/
    ├── sem_orders.yml        # Semantic model + metrics for orders
    ├── metricflow_time_spine.sql
    └── sem_metricflow_time_spine.yml
```

**Why:** Clear separation, easier to find semantic layer components.

---

### Naming with sem_ Prefix

Use `sem_` prefix for semantic model YAML files.

**Pattern:**
```
sem_orders.yml       # Semantic model for orders
sem_customers.yml    # Semantic model for customers
sem_products.yml     # Semantic model for products
```

**Why:** Distinguishes semantic layer files from regular model schema files.

---

## Common Anti-Patterns to Avoid

### ❌ Nesting Metrics in Measures

**Don't:**
```yaml
measures:
  - name: revenue_per_customer
    agg: average
    expr: order_amount / customer_count
```

**Do:**
```yaml
# Create atomic measures
measures:
  - name: total_revenue
    agg: sum
    expr: order_amount

  - name: unique_customers
    agg: count_distinct
    expr: customer_id

# Create derived metric
metrics:
  - name: revenue_per_customer
    type: derived
    type_params:
      expr: total_revenue / unique_customers
      metrics:
        - name: total_revenue
        - name: unique_customers
```

---

### ❌ Hardcoding Business Logic in dbt Models

**Don't:**
```sql
-- In dbt model
select
    order_id,
    case
        when total_amount > 1000 then 'High Value'
        else 'Standard'
    end as order_tier
```

**Do:**
```yaml
# In semantic model dimension
dimensions:
  - name: order_tier
    type: categorical
    expr: >
      case
        when total_amount > 1000 then 'High Value'
        else 'Standard'
      end
```

**Why:** Business logic belongs in the semantic layer for reusability and consistency.

---

### ❌ Creating Duplicate Measures

**Don't:**
```yaml
# In orders semantic model
measures:
  - name: order_revenue
    agg: sum
    expr: order_amount

# In transactions semantic model
measures:
  - name: transaction_revenue  # Duplicate concept!
    agg: sum
    expr: transaction_amount
```

**Do:**
Use consistent naming and consolidate similar measures where possible.

---

## Performance Optimization

### Materialization Strategy

Materialize underlying dbt models as tables for better query performance.

**Pattern:**
```sql
-- In fct_orders.sql
{{
  config(
    materialized='table'  # Not view
  )
}}
```

**Why:** MetricFlow generates complex joins - table materialization improves query speed.

---

### Selective Dimension Exposure

Only expose dimensions that will be used for grouping or filtering.

**Pattern:**
```yaml
# Include commonly used dimensions
dimensions:
  - name: order_date
  - name: customer_region
  - name: product_category

# Omit rarely used attributes
# (Keep in underlying dbt model but don't expose as dimensions)
```

**Why:** Reduces semantic graph complexity and improves query planning.

---

## Summary

**Key Takeaways:**
1. Start with fact tables and atomic measures
2. Use singular entity names and keep them consistent
3. Progress from simple → ratio → derived metrics
4. Document grain, business logic, and calculation details
5. Test iteratively with CLI commands
6. Organize in dedicated subfolder with `sem_` prefix
7. Avoid nesting logic - keep measures atomic
8. Use computed dimensions instead of hardcoding in models
