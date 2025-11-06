# dbt Best Practices Reference

## SQL Style Guide

### CTE Naming Patterns

Use descriptive, progressive CTE names that tell the story of the transformation:

**Standard progression:**
1. `source` - Direct source reference
2. `renamed` - Column renaming and basic casting
3. `filtered` - Apply WHERE clauses
4. `joined` - Join with other tables
5. `aggregated` - GROUP BY logic
6. `pivoted` - Pivot transformations
7. `final` - Final shape and selection

**Example:**

```sql
with source as (
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        order_date as ordered_at,
        status as order_status
    from source
),

filtered as (
    select * from renamed
    where order_status != 'cancelled'
),

final as (
    select * from filtered
)

select * from final
```

### Column Ordering Standards

Organize columns in this sequence for consistency:

1. **Primary key** - Unique identifier for the record
2. **Foreign keys** - References to dimension tables
3. **Degenerate dimensions** - Non-dimensional attributes (codes, flags)
4. **Measures/Metrics** - Numeric values, counts, amounts
5. **Descriptive attributes** - Text fields, names, descriptions
6. **Date/time attributes** - Temporal fields
7. **Audit fields** - created_at, updated_at, loaded_at

**Example:**

```sql
select
    -- Primary key
    order_key,

    -- Foreign keys
    customer_key,
    product_key,
    date_key,

    -- Degenerate dimensions
    order_number,
    order_status,

    -- Measures
    quantity,
    unit_price,
    total_amount,

    -- Descriptive attributes
    shipping_address,
    special_instructions,

    -- Date/time attributes
    ordered_at,
    shipped_at,
    delivered_at,

    -- Audit fields
    created_at,
    updated_at
from final
```

### Naming Conventions

**Models:**
- `stg_[source]_[entity]` - Staging models (e.g., `stg_shopify_orders`)
- `int_[entity]_[verb]` - Intermediate models (e.g., `int_orders_pivoted`)
- `fct_[entity]` - Fact tables (e.g., `fct_orders`)
- `dim_[entity]` - Dimension tables (e.g., `dim_customers`)

**Columns:**
- Use `snake_case` for all column names
- Boolean fields: `is_[property]` or `has_[property]` (e.g., `is_active`, `has_shipped`)
- Dates: `[event]_date` or `[event]_at` (e.g., `order_date`, `created_at`)
- Counts: `[entity]_count` (e.g., `order_count`)
- Amounts: `[type]_amount` (e.g., `total_amount`, `tax_amount`)
- Keys: `[entity]_key` for surrogate keys, `[entity]_id` for natural keys

**Tags:**
- Layer: `staging`, `intermediate`, `mart`
- Entity type: `fact`, `dimension`
- Update frequency: `daily`, `hourly`, `weekly`
- Business domain: `finance`, `operations`, `marketing`
- Criticality: `core`, `critical`, `experimental`

### SQL Formatting

**Indentation:**
- Use 4 spaces (not tabs)
- Indent nested SELECT statements
- Align closing parentheses with opening statement

**SELECT statements:**
- One column per line
- Comma-first or comma-last (be consistent)
- Group related columns with blank lines

**Comma-last style (recommended):**

```sql
select
    order_id,
    customer_id,
    order_date,

    quantity,
    unit_price,
    total_amount

from orders
```

**WHERE clauses:**
- One condition per line for complex filters
- Use AND/OR at start of line

```sql
where
    order_status = 'completed'
    and order_date >= '2024-01-01'
    and (
        total_amount > 1000
        or customer_tier = 'premium'
    )
```

**JOINs:**
- One JOIN per line
- Specify join type explicitly (INNER, LEFT, RIGHT, FULL)
- Use USING when column names match, ON for different names

```sql
from orders
inner join customers using (customer_id)
left join products on orders.product_id = products.id
```

### Comments

**When to comment:**
- Complex business logic or calculations
- Non-obvious transformations
- Temporary workarounds or known issues
- Performance considerations

**Style:**

```sql
-- Single-line comments for brief explanations
select
    -- Calculate poverty score: (green×3 + yellow×2 + red×1) / (total×3)
    (green_count * 3 + yellow_count * 2 + red_count * 1) /
        (total_indicators * 3.0) as poverty_score
```

**Block comments for major sections:**

```sql
/*
 * Pivot indicator responses from rows to columns
 * Each indicator becomes its own column with the stoplight value
 * This enables easier comparison across indicators for a single family
 */
with pivoted as (
    ...
)
```

## Transformation Patterns

### Surrogate Key Generation

Use `dbt_utils.generate_surrogate_key()` for consistent hashing:

```sql
select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'order_date']) }} as order_key,
    customer_id,
    order_date,
    ...
from orders
```

### Timestamp Conversions

**From Unix milliseconds:**

```sql
to_timestamp(created_at_ms / 1000) as created_at
```

**To date keys (YYYYMMDD format):**

```sql
to_char(order_date, 'YYYYMMDD')::integer as order_date_key
```

### Handling NULL Values

**COALESCE for defaults:**

```sql
select
    coalesce(order_count, 0) as order_count,
    coalesce(total_amount, 0.0) as total_amount,
    coalesce(customer_name, 'Unknown') as customer_name
```

**NULLIF to create NULLs:**

```sql
select
    nullif(status, '') as status,  -- Empty string becomes NULL
    nullif(amount, 0) as amount    -- Zero becomes NULL
```

### Window Functions

**Numbering rows:**

```sql
select
    customer_id,
    order_date,
    row_number() over (
        partition by customer_id
        order by order_date
    ) as order_sequence
```

**Latest value per group:**

```sql
select
    customer_id,
    first_value(order_date) over (
        partition by customer_id
        order by order_date desc
    ) as last_order_date
```

**Running totals:**

```sql
select
    order_date,
    order_amount,
    sum(order_amount) over (
        order by order_date
        rows between unbounded preceding and current row
    ) as running_total
```

### Deduplication

**Keep most recent:**

```sql
with ranked as (
    select
        *,
        row_number() over (
            partition by customer_id
            order by updated_at desc
        ) as rn
    from customers
)

select * from ranked
where rn = 1
```

**Keep first occurrence:**

```sql
select distinct on (customer_id)
    customer_id,
    customer_name,
    created_at
from customers
order by customer_id, created_at
```

### Slowly Changing Dimensions (SCD Type 2)

Track historical changes with effective dates:

```sql
select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'effective_from']) }} as customer_key,
    customer_id,
    customer_name,
    customer_tier,
    effective_from,
    effective_to,
    case
        when effective_to is null then true
        else false
    end as is_current
from customer_history
```

### Conditional Aggregation

**Using CASE within aggregates:**

```sql
select
    customer_id,
    count(*) as total_orders,
    count(case when order_status = 'completed' then 1 end) as completed_orders,
    count(case when order_status = 'cancelled' then 1 end) as cancelled_orders,
    sum(case when order_status = 'completed' then order_amount else 0 end) as total_revenue
from orders
group by 1
```

**Using FILTER (PostgreSQL):**

```sql
select
    customer_id,
    count(*) as total_orders,
    count(*) filter (where order_status = 'completed') as completed_orders,
    sum(order_amount) filter (where order_status = 'completed') as total_revenue
from orders
group by 1
```

## Testing Strategies

### Test Pyramid

1. **Schema tests** (80%) - Fast, comprehensive coverage of basic constraints
2. **Custom SQL tests** (15%) - Business logic validation
3. **Data quality tests** (5%) - Distribution checks, anomaly detection

### Key Testing Patterns

**Primary keys:**

```yaml
- name: order_key
  data_tests:
    - unique
    - not_null
```

**Foreign keys:**

```yaml
- name: customer_key
  data_tests:
    - not_null
    - relationships:
        to: ref('dim_customers')
        field: customer_key
```

**Categorical values:**

```yaml
- name: order_status
  data_tests:
    - accepted_values:
        values: ['pending', 'processing', 'shipped', 'delivered', 'cancelled']
```

**Numeric ranges:**

```yaml
- name: quantity
  data_tests:
    - dbt_utils.expression_is_true:
        expression: ">= 0"
    - dbt_expectations.expect_column_values_to_be_between:
        min_value: 0
        max_value: 1000
```

**Conditional tests:**

```yaml
- name: shipped_date
  data_tests:
    - not_null:
        config:
          where: "order_status in ('shipped', 'delivered')"
```

### Custom Test Example

Create `tests/assert_valid_poverty_scores.sql`:

```sql
-- Test that poverty scores are between 0 and 1
select
    family_id,
    poverty_score
from {{ ref('fct_family_scores') }}
where
    poverty_score < 0
    or poverty_score > 1
```

## Performance Optimization

### Materialization Strategy

**Views (default for staging):**
- No storage overhead
- Always fresh data
- Good for simple transformations
- Use when: downstream models are small, logic is lightweight

**Tables (default for marts):**
- Stored on disk
- Faster query performance
- Use when: complex logic, large datasets, frequently queried

**Ephemeral:**
- Compiled as CTEs in dependent models
- No separate object created
- Use when: simple transformations used by single model

### Index Considerations

While dbt doesn't directly create indexes, design with them in mind:

**Good candidates for indexes:**
- Primary keys
- Foreign keys
- Frequently filtered columns
- Columns used in JOINs
- Columns used in ORDER BY

Document index recommendations in model descriptions:

```yaml
meta:
  indexes:
    - columns: ['customer_key']
      unique: true
    - columns: ['order_date', 'order_status']
      unique: false
```

### Join Optimization

**Order of joins:**
- Start with smallest table
- Apply filters before joins when possible
- Use INNER JOIN to reduce row count early

**Example:**

```sql
-- Less efficient: filter after join
select *
from large_table
left join small_table using (id)
where large_table.status = 'active'

-- More efficient: filter before join
with filtered_large as (
    select * from large_table
    where status = 'active'
)

select *
from filtered_large
left join small_table using (id)
```

### Aggregation Optimization

**Pre-aggregate when possible:**

```sql
-- Instead of joining then aggregating
with orders_aggregated as (
    select
        customer_id,
        count(*) as order_count,
        sum(total_amount) as lifetime_value
    from orders
    group by 1
)

select
    customers.*,
    orders_aggregated.order_count,
    orders_aggregated.lifetime_value
from customers
left join orders_aggregated using (customer_id)
```

## Documentation Standards

### Model-Level Documentation

```yaml
models:
  - name: fct_orders
    description: >
      Order transactions at atomic grain. One row per order line item.

      **Grain:** One row per order line item (order_id, line_number)

      **Refresh:** Daily at 2 AM UTC

      **Upstream dependencies:**
      - stg_shopify_orders
      - dim_customers
      - dim_products

      **Business logic:**
      - Excludes cancelled orders
      - Applies exchange rate conversion for international orders
      - Calculates tax based on shipping destination
    meta:
      owner: analytics_team
      contains_pii: false
      estimated_rows: 5000000
```

### Column-Level Documentation

```yaml
columns:
  - name: order_key
    description: >
      Surrogate key generated from order_id and line_number.
      Unique identifier for each order line item in the warehouse.

  - name: unit_price_usd
    description: >
      Price per unit in USD. Converted from local currency using
      daily exchange rates from dim_exchange_rates.
      NULL if exchange rate unavailable.
```

### dbt Project Documentation

**In dbt_project.yml:**

```yaml
name: psp_data_build
version: 1.0.0
config-version: 2

profile: default

vars:
  start_date: '2020-01-01'  # Historical data cutoff
  exclude_test_data: true   # Filter test families

models:
  psp_data_build:
    +persist_docs:
      relation: true
      columns: true
```

## Version Control Best Practices

### Git Workflow

1. **Branch naming:** `feature/model-name` or `fix/issue-description`
2. **Commit messages:** Clear, descriptive (e.g., "Add dim_organization model with hierarchy")
3. **PR scope:** Keep changes focused - one model or related set
4. **Code review:** Review SQL logic, test coverage, documentation

### What to Commit

**DO commit:**
- Model SQL files
- Schema YAML files
- Custom tests
- Macros
- dbt_project.yml
- Source definitions

**DON'T commit:**
- target/ directory (compiled files)
- dbt_packages/ directory (installed packages)
- logs/ directory
- .env files (credentials)
- profiles.yml (local database connections)

### .gitignore for dbt

```gitignore
target/
dbt_packages/
logs/
.env
profiles.yml
```
