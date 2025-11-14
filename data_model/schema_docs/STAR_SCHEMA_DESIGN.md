# Star Schema Design
## Poverty Stoplight Data Warehouse

**Version:** 1.0
**Date:** 2025-01-06
**Grain:** Family-Indicator-Snapshot Level

---

## Schema Overview

**Business Process:** Family poverty assessment surveys where families self-assess their status on multiple indicators using the stoplight methodology, plus economic survey responses

**Fact Table Grain:**
- **Stoplight Indicators:** One row per family, per indicator, per snapshot (survey completion)
- **Economic Data:** One row per family, per economic question, per snapshot (survey completion)

**Number of Star Schemas:** 2 related schemas sharing common dimensions (date, family, organization, survey_definition)

---

## Fact Table: fact_family_indicator_snapshot

**Description:** Stores poverty indicator assessments at the most atomic level

**Characteristics:**
- Very long table (millions of rows)
- Narrow table (mostly keys + one main measure)
- Each row represents one indicator result for one family in one survey

### Columns

**Surrogate Key:**
- `family_indicator_snapshot_key` (BIGINT, PRIMARY KEY) - Surrogate key for grain uniqueness

**Foreign Keys to Dimensions:**
- `date_key` (INTEGER, NOT NULL) - FK to dim_date (survey date)
- `organization_key` (BIGINT, NOT NULL) - FK to dim_organization
- `indicator_key` (BIGINT, NOT NULL) - FK to dim_indicator
- `family_key` (BIGINT, NOT NULL) - FK to dim_family
- `survey_definition_key` (BIGINT, NOT NULL) - FK to dim_survey_definition

**Degenerate Dimensions:**
- `snapshot_id` (BIGINT, NOT NULL) - Natural key from source system (data_collect.snapshot.id)
- `snapshot_number` (SMALLINT, NOT NULL) - Survey round (1=baseline, 2=first follow-up, 3=second follow-up, etc.)
- `is_last` (BOOLEAN, NOT NULL) - Flag indicating if this is the most recent survey for this family

**Measures:**
- `indicator_status_value` (SMALLINT) - Poverty status value
  - 1 = Red (Critical poverty)
  - 2 = Yellow (Moderate poverty/vulnerability)
  - 3 = Green (Non-poor/adequate)
  - NULL = Skipped/Not answered

**Indexes:**
- Primary key on `family_indicator_snapshot_key`
- Composite index on (`family_key`, `indicator_key`, `snapshot_id`)
- Index on `date_key`
- Index on `is_last` (for current status queries)
- Index on `snapshot_number` (for baseline/follow-up filtering)

---

## Fact Table: fact_family_economic_snapshot

**Description:** Stores economic survey responses at the most atomic level

**Characteristics:**
- Atomic grain (one row per family, per economic question, per snapshot)
- Sparse matrix structure with type-specific columns for multi-type fields
- Filtered data (excludes 244 orphaned code_names via inner join in staging)

### Columns

**Surrogate Key:**
- `family_economic_snapshot_key` (BIGINT, PRIMARY KEY) - Surrogate key for grain uniqueness

**Foreign Keys to Dimensions:**
- `date_key` (INTEGER, NOT NULL) - FK to dim_date (survey date)
- `family_key` (BIGINT, NOT NULL) - FK to dim_family
- `economic_question_key` (BIGINT, NOT NULL) - FK to dim_economic_questions
- `organization_key` (BIGINT, NOT NULL) - FK to dim_organization
- `survey_definition_key` (BIGINT, NOT NULL) - FK to dim_survey_definition

**Degenerate Dimensions:**
- `snapshot_id` (BIGINT, NOT NULL) - Natural key from source system (data_collect.snapshot.id)
- `snapshot_number` (SMALLINT, NOT NULL) - Survey round (1=baseline, 2=first follow-up, etc.)
- `is_last` (BOOLEAN, NOT NULL) - Flag indicating if this is the most recent survey for this family

**Measures (5 Priority Economic Fields):**

1. **householdMonthlyIncome:**
   - `household_monthly_income` (NUMERIC(15,2)) - Monthly household income value
   - `income_currency_code` (VARCHAR(10)) - Currency code (e.g., 'USD', 'BRL')

2. **housingSituation:**
   - `housing_situation_single` (VARCHAR(255)) - Single-select response (select/radio types)
   - `housing_situation_multi` (TEXT) - Multi-select response (checkbox type)

3. **activityMain:**
   - `activity_main_single` (VARCHAR(255)) - Single-select response (select/radio types)
   - `activity_main_multi` (TEXT) - Multi-select response (checkbox type)
   - `activity_main_text` (TEXT) - Free text response

4. **familyCar:**
   - `family_car` (BOOLEAN) - Boolean indicating car ownership

5. **areaOfResidence:**
   - `area_of_residence_select` (VARCHAR(255)) - Detailed area select response
   - `area_of_residence_radio` (VARCHAR(100)) - Binary urban/rural radio response

**Indexes:**
- Primary key on `family_economic_snapshot_key`
- Natural key composite on (`snapshot_id`, `economic_question_key`)
- Index on `date_key`
- Index on `family_key`
- Index on `economic_question_key`
- Index on `organization_key`
- Index on `survey_definition_key`
- Index on `is_last` (for current status queries)
- Index on `snapshot_number` (for baseline/follow-up filtering)
- Composite index on (`family_key`, `snapshot_id`)

---

## Dimension Tables

### dim_date

**Description:** Standard date dimension for survey dates

**Type:** Conformed dimension (can be reused across multiple fact tables)

**Grain:** One row per calendar day

**SCD Type:** Not applicable (static calendar)

#### Columns

- `date_key` (INTEGER, PRIMARY KEY) - Surrogate key in YYYYMMDD format (e.g., 20240315)
- `date_actual` (DATE, NOT NULL) - The actual calendar date
- `day_of_week` (VARCHAR(10), NOT NULL) - Day name (Monday, Tuesday, etc.)
- `day_of_week_number` (SMALLINT, NOT NULL) - Day number (1=Monday, 7=Sunday)
- `day_of_month` (SMALLINT, NOT NULL) - Day of month (1-31)
- `day_of_year` (SMALLINT, NOT NULL) - Day of year (1-366)
- `week_of_year` (SMALLINT, NOT NULL) - ISO week number (1-53)
- `month_number` (SMALLINT, NOT NULL) - Month number (1-12)
- `month_name` (VARCHAR(10), NOT NULL) - Month name (January, February, etc.)
- `month_abbr` (VARCHAR(3), NOT NULL) - Month abbreviation (Jan, Feb, etc.)
- `quarter_number` (SMALLINT, NOT NULL) - Quarter number (1-4)
- `quarter_name` (VARCHAR(2), NOT NULL) - Quarter name (Q1, Q2, Q3, Q4)
- `year_number` (SMALLINT, NOT NULL) - Year (e.g., 2024)
- `year_quarter` (VARCHAR(7), NOT NULL) - Year-Quarter (e.g., "2024-Q1")
- `year_month` (VARCHAR(7), NOT NULL) - Year-Month (e.g., "2024-01")
- `is_weekend` (BOOLEAN, NOT NULL) - True if Saturday or Sunday

---

### dim_organization

**Description:** Organizational hierarchy dimension (Application > Organization)

**Type:** Slowly changing dimension

**Grain:** One row per organization

**SCD Type:** Type 1 (overwrite changes)

**Hierarchy:** Application (Hub) > Organization

#### Columns

**Surrogate Key:**
- `organization_key` (BIGINT, PRIMARY KEY) - Surrogate key

**Organization Level:**
- `organization_id` (BIGINT, NOT NULL, UNIQUE) - Natural key from ps_network.organizations
- `organization_name` (VARCHAR(255), NOT NULL) - Organization name
- `organization_description` (VARCHAR(255)) - Organization description
- `organization_is_active` (BOOLEAN, NOT NULL) - If organization is currently active
- `organization_country` (VARCHAR(100)) - Organization country name
- `organization_country_code` (VARCHAR(10)) - Organization ISO country code
- `organization_type` (VARCHAR(100)) - Type of organization

**Application Level (Hierarchy):**
- `application_id` (BIGINT, NOT NULL) - Natural key from ps_network.applications
- `application_name` (VARCHAR(255), NOT NULL) - Application/Hub name
- `application_description` (VARCHAR(255)) - Application description
- `application_is_active` (BOOLEAN, NOT NULL) - If application is currently active
- `application_country` (VARCHAR(100)) - Application country name
- `application_country_code` (VARCHAR(10)) - Application ISO country code

**Indexes:**
- Primary key on `organization_key`
- Unique index on `organization_id`
- Index on `application_id` (for hierarchy queries)

---

### dim_indicator

**Description:** Indicator hierarchy dimension (Dimension Category > Indicator)

**Type:** Slowly changing dimension

**Grain:** One row per survey indicator (survey_stoplight record)

**SCD Type:** Type 1 (overwrite changes)

**Hierarchy:** Dimension (6 categories) > Indicator

#### Columns

**Surrogate Key:**
- `indicator_key` (BIGINT, PRIMARY KEY) - Surrogate key

**Indicator Level:**
- `indicator_id` (BIGINT, NOT NULL, UNIQUE) - Natural key from data_collect.survey_stoplight
- `indicator_code_name` (VARCHAR(255), NOT NULL) - Unique indicator code
- `indicator_short_name` (VARCHAR(255), NOT NULL) - Short display name
- `indicator_question_text` (VARCHAR(300)) - Full question text
- `indicator_description` (TEXT) - Detailed description/definition
- `indicator_is_required` (BOOLEAN) - If indicator is required in survey

**Dimension Level (Hierarchy):**
- `dimension_id` (BIGINT, NOT NULL) - Natural key for dimension category
- `dimension_name` (VARCHAR(100), NOT NULL) - Dimension category name
  - "Education and Culture"
  - "Health and Environment"
  - "Housing and Infrastructure"
  - "Income and Employment"
  - "Interiority and Motivation"
  - "Organization and Participation"
- `dimension_code` (VARCHAR(50)) - Dimension code/abbreviation

**Template Reference:**
- `indicator_template_id` (BIGINT) - FK to survey_stoplight_indicator (master template)
- `indicator_template_code_name` (VARCHAR(255)) - Template code name for lineage

**Indexes:**
- Primary key on `indicator_key`
- Unique index on `indicator_id`
- Index on `dimension_id` (for hierarchy queries)
- Index on `indicator_code_name` (for code-based lookups)

---

### dim_family

**Description:** Family identity and geography dimension

**Type:** Slowly changing dimension

**Grain:** One row per family

**SCD Type:** Type 1 (overwrite changes)

#### Columns

**Surrogate Key:**
- `family_key` (BIGINT, PRIMARY KEY) - Surrogate key

**Family Identity:**
- `family_id` (BIGINT, NOT NULL, UNIQUE) - Natural key from ps_families.family
- `family_code` (VARCHAR(255), NOT NULL) - Unique family code
- `family_name` (VARCHAR(300)) - Family name ('ANON_DATA' if anonymous)
- `family_is_active` (BOOLEAN, NOT NULL) - If family is currently active
- `is_anonymous` (BOOLEAN, NOT NULL) - If family data is anonymized

**Geography:**
- `country` (VARCHAR(100)) - Country name
- `country_code` (VARCHAR(10)) - ISO country code (birth country from family members)
- `latitude` (DECIMAL(10,7)) - GPS latitude coordinate
- `longitude` (DECIMAL(10,7)) - GPS longitude coordinate
- `address` (VARCHAR(200)) - Physical address
- `post_code` (VARCHAR(50)) - Postal code

**Indexes:**
- Primary key on `family_key`
- Unique index on `family_id`
- Unique index on `family_code`
- Index on `country_code` (for geographic filtering)
- Spatial index on (`latitude`, `longitude`) if supported by database

---

### dim_survey_definition

**Description:** Survey template/definition dimension

**Type:** Slowly changing dimension

**Grain:** One row per survey definition (template)

**SCD Type:** Type 1 (overwrite changes)

#### Columns

**Surrogate Key:**
- `survey_definition_key` (BIGINT, PRIMARY KEY) - Surrogate key

**Survey Definition:**
- `survey_definition_id` (BIGINT, NOT NULL, UNIQUE) - Natural key from data_collect.survey_definition
- `survey_code` (VARCHAR(255)) - Unique survey code
- `survey_title` (VARCHAR(255), NOT NULL) - Survey title
- `survey_description` (VARCHAR(255)) - Survey description
- `survey_language` (VARCHAR(50)) - Survey language code
- `survey_country_code` (VARCHAR(10)) - Country code for survey
- `survey_is_active` (BOOLEAN, NOT NULL) - If survey is currently active
- `survey_status` (VARCHAR(50)) - Survey status (draft, active, archived, etc.)
- `survey_is_current` (BOOLEAN) - If this is the current version

**Indexes:**
- Primary key on `survey_definition_key`
- Unique index on `survey_definition_id`
- Index on `survey_code` (for code-based lookups)

---

### dim_economic_questions

**Description:** Economic question dimension containing metadata about economic survey questions

**Type:** Slowly changing dimension

**Grain:** One row per economic question per survey definition (survey_definition_id + code_name)

**SCD Type:** Type 1 (overwrite changes)

#### Columns

**Surrogate Key:**
- `economic_question_key` (BIGINT, PRIMARY KEY) - Surrogate key

**Natural Keys:**
- `survey_definition_id` (BIGINT, NOT NULL, UNIQUE with code_name) - FK to survey_definition
- `code_name` (VARCHAR(255), NOT NULL, UNIQUE with survey_definition_id) - Question identifier

**Question Attributes:**
- `question_text` (TEXT) - Question displayed to families during survey
- `answer_type` (VARCHAR(50), NOT NULL) - Response format: text, number, date, select, radio, checkbox
- `answer_options` (TEXT) - Available choices for select/radio/checkbox types
- `scope` (VARCHAR(50)) - Question scope: family-level or member-level
- `is_for_family_member` (BOOLEAN) - True if question applies to individual family members

**Survey Context:**
- `survey_code` (VARCHAR(255)) - Survey code from survey_definition
- `survey_title` (VARCHAR(255)) - Survey title from survey_definition
- `survey_language` (VARCHAR(50)) - Survey language code (e.g., 'en', 'es', 'pt')

**Indexes:**
- Primary key on `economic_question_key`
- Unique composite key on (`survey_definition_id`, `code_name`)
- Index on `survey_definition_id` (for FK queries)
- Index on `code_name` (for code-based lookups)
- Index on `answer_type` (for filtering by response type)