# Schema Reference - Detailed Column Specifications
## Poverty Stoplight Data Warehouse

**Purpose:** Detailed technical specifications for all tables in the star schema

---

## FACT TABLE

### fact_family_indicator_snapshot

**Description:** Captures poverty indicator assessments at the atomic grain

**Grain:** One row per family, per indicator, per snapshot (survey completion)

**Estimated Row Count:** 225,000 current, growing by ~75K per 1,000 new families

---

#### Column Specifications

| Column Name | Data Type | Nullable | Default | Constraints | Description |
|-------------|-----------|----------|---------|-------------|-------------|
| `family_indicator_snapshot_key` | BIGINT | NOT NULL | - | PRIMARY KEY | Surrogate key for this fact record |
| `date_key` | INTEGER | NOT NULL | - | FK → dim_date.date_key | Survey date key (YYYYMMDD format) |
| `organization_key` | BIGINT | NOT NULL | - | FK → dim_organization.organization_key | Organization conducting survey |
| `indicator_key` | BIGINT | NOT NULL | - | FK → dim_indicator.indicator_key | Indicator being assessed |
| `family_key` | BIGINT | NOT NULL | - | FK → dim_family.family_key | Family being assessed |
| `survey_definition_key` | BIGINT | NOT NULL | - | FK → dim_survey_definition.survey_definition_key | Survey template used |
| `snapshot_id` | BIGINT | NOT NULL | - | UNIQUE INDEX (with family_key, indicator_key) | Natural key from source (data_collect.snapshot.id) |
| `snapshot_number` | SMALLINT | NOT NULL | - | CHECK (snapshot_number > 0) | Survey round: 1=baseline, 2=first follow-up, etc. |
| `is_last` | BOOLEAN | NOT NULL | FALSE | INDEX | True if this is the most recent survey for this family |
| `indicator_status_value` | SMALLINT | NULL | - | CHECK (indicator_status_value IN (1,2,3) OR indicator_status_value IS NULL) | Stoplight status: 1=Red, 2=Yellow, 3=Green, NULL=Skipped |

#### Indexes

```sql
-- Primary key
CREATE UNIQUE INDEX idx_fact_pk ON fact_family_indicator_snapshot (family_indicator_snapshot_key);

-- Natural key for deduplication
CREATE UNIQUE INDEX idx_fact_natural_key ON fact_family_indicator_snapshot (snapshot_id, indicator_key);

-- Foreign key indexes for join performance
CREATE INDEX idx_fact_date ON fact_family_indicator_snapshot (date_key);
CREATE INDEX idx_fact_org ON fact_family_indicator_snapshot (organization_key);
CREATE INDEX idx_fact_indicator ON fact_family_indicator_snapshot (indicator_key);
CREATE INDEX idx_fact_family ON fact_family_indicator_snapshot (family_key);
CREATE INDEX idx_fact_survey_def ON fact_family_indicator_snapshot (survey_definition_key);

-- Query optimization indexes
CREATE INDEX idx_fact_is_last ON fact_family_indicator_snapshot (is_last) WHERE is_last = TRUE;
CREATE INDEX idx_fact_snapshot_num ON fact_family_indicator_snapshot (snapshot_number);

-- Composite indexes for common queries
CREATE INDEX idx_fact_family_snapshot ON fact_family_indicator_snapshot (family_key, snapshot_id);
CREATE INDEX idx_fact_indicator_status ON fact_family_indicator_snapshot (indicator_key, indicator_status_value);
```

#### Source Mapping

| Target Column | Source Table | Source Column | Transformation |
|---------------|--------------|---------------|----------------|
| `snapshot_id` | data_collect.snapshot | id | Direct mapping |
| `snapshot_number` | data_collect.snapshot | snapshot_number | Direct mapping |
| `is_last` | data_collect.snapshot | is_last | Direct mapping |
| `indicator_status_value` | data_collect.snapshot_stoplight | value | Direct mapping (1/2/3 or NULL) |
| `date_key` | data_collect.snapshot | snapshot_date | Convert to YYYYMMDD format |

---

## DIMENSION TABLES

### dim_date

**Description:** Standard date dimension for time-based analysis

**Grain:** One row per calendar day

**Row Count:** ~7,300 rows (20 years of dates)

---

#### Column Specifications

| Column Name | Data Type | Nullable | Default | Constraints | Description |
|-------------|-----------|----------|---------|-------------|-------------|
| `date_key` | INTEGER | NOT NULL | - | PRIMARY KEY | Surrogate key in YYYYMMDD format (e.g., 20240315) |
| `date_actual` | DATE | NOT NULL | - | UNIQUE | The actual calendar date |
| `day_of_week` | VARCHAR(10) | NOT NULL | - | - | Full day name: Monday, Tuesday, etc. |
| `day_of_week_number` | SMALLINT | NOT NULL | - | CHECK (1-7) | ISO day number: 1=Monday, 7=Sunday |
| `day_of_month` | SMALLINT | NOT NULL | - | CHECK (1-31) | Day of month |
| `day_of_year` | SMALLINT | NOT NULL | - | CHECK (1-366) | Day of year |
| `week_of_year` | SMALLINT | NOT NULL | - | CHECK (1-53) | ISO week number |
| `month_number` | SMALLINT | NOT NULL | - | CHECK (1-12) | Month number |
| `month_name` | VARCHAR(10) | NOT NULL | - | - | Full month name: January, February, etc. |
| `month_abbr` | VARCHAR(3) | NOT NULL | - | - | Month abbreviation: Jan, Feb, etc. |
| `quarter_number` | SMALLINT | NOT NULL | - | CHECK (1-4) | Calendar quarter number |
| `quarter_name` | VARCHAR(2) | NOT NULL | - | - | Quarter name: Q1, Q2, Q3, Q4 |
| `year_number` | SMALLINT | NOT NULL | - | - | Four-digit year (e.g., 2024) |
| `year_quarter` | VARCHAR(7) | NOT NULL | - | - | Year-Quarter format: "2024-Q1" |
| `year_month` | VARCHAR(7) | NOT NULL | - | - | Year-Month format: "2024-01" |
| `is_weekend` | BOOLEAN | NOT NULL | FALSE | - | True if Saturday or Sunday |

#### Indexes

```sql
CREATE UNIQUE INDEX idx_date_pk ON dim_date (date_key);
CREATE UNIQUE INDEX idx_date_actual ON dim_date (date_actual);
CREATE INDEX idx_date_year ON dim_date (year_number);
CREATE INDEX idx_date_year_month ON dim_date (year_month);
CREATE INDEX idx_date_year_quarter ON dim_date (year_quarter);
```

---

### dim_organization

**Description:** Organizational hierarchy (Application > Organization)

**Grain:** One row per organization

**Row Count:** ~100-500 organizations

---

#### Column Specifications

| Column Name | Data Type | Nullable | Default | Constraints | Description |
|-------------|-----------|----------|---------|-------------|-------------|
| `organization_key` | BIGINT | NOT NULL | - | PRIMARY KEY | Surrogate key |
| `organization_id` | BIGINT | NOT NULL | - | UNIQUE | Natural key from ps_network.organizations.id |
| `organization_name` | VARCHAR(255) | NOT NULL | - | - | Organization name |
| `organization_description` | VARCHAR(255) | NULL | - | - | Organization description |
| `organization_is_active` | BOOLEAN | NOT NULL | TRUE | - | Current active status |
| `organization_country` | VARCHAR(100) | NULL | - | - | Organization country name |
| `organization_country_code` | VARCHAR(10) | NULL | - | - | ISO country code |
| `organization_type` | VARCHAR(100) | NULL | - | - | Type of organization |
| `application_id` | BIGINT | NOT NULL | - | - | Natural key from ps_network.applications.id |
| `application_name` | VARCHAR(255) | NOT NULL | - | - | Application/Hub name |
| `application_description` | VARCHAR(255) | NULL | - | - | Application description |
| `application_is_active` | BOOLEAN | NOT NULL | TRUE | - | Application active status |
| `application_country` | VARCHAR(100) | NULL | - | - | Application country name |
| `application_country_code` | VARCHAR(10) | NULL | - | - | Application ISO country code |

#### Indexes

```sql
CREATE UNIQUE INDEX idx_org_pk ON dim_organization (organization_key);
CREATE UNIQUE INDEX idx_org_natural_key ON dim_organization (organization_id);
CREATE INDEX idx_org_application ON dim_organization (application_id);
CREATE INDEX idx_org_name ON dim_organization (organization_name);
CREATE INDEX idx_org_country ON dim_organization (organization_country_code);
```

#### Source Mapping

| Target Column | Source Table | Source Column | Transformation |
|---------------|--------------|---------------|----------------|
| `organization_id` | ps_network.organizations | id | Direct mapping |
| `organization_name` | ps_network.organizations | name | Direct mapping |
| `organization_is_active` | ps_network.organizations | is_active | Direct mapping |
| `organization_country_code` | ps_network.organizations | country_code | Direct mapping |
| `application_id` | ps_network.applications | id | Join via organizations.application_id |
| `application_name` | ps_network.applications | name | Join via organizations.application_id |

---

### dim_indicator

**Description:** Indicator hierarchy (Dimension > Indicator)

**Grain:** One row per survey indicator (survey_stoplight instance)

**Row Count:** ~500-1,000 indicators

---

#### Column Specifications

| Column Name | Data Type | Nullable | Default | Constraints | Description |
|-------------|-----------|----------|---------|-------------|-------------|
| `indicator_key` | BIGINT | NOT NULL | - | PRIMARY KEY | Surrogate key |
| `indicator_id` | BIGINT | NOT NULL | - | UNIQUE | Natural key from data_collect.survey_stoplight.id |
| `indicator_code_name` | VARCHAR(255) | NOT NULL | - | INDEX | Unique indicator code |
| `indicator_short_name` | VARCHAR(255) | NOT NULL | - | - | Short display name |
| `indicator_question_text` | VARCHAR(300) | NULL | - | - | Full question text shown to families |
| `indicator_description` | TEXT | NULL | - | - | Detailed description/aspirational text |
| `indicator_is_required` | BOOLEAN | NULL | FALSE | - | Whether indicator is required in survey |
| `dimension_id` | BIGINT | NOT NULL | - | INDEX | Natural key for dimension category |
| `dimension_name` | VARCHAR(100) | NOT NULL | - | INDEX | Dimension category name (one of 6 categories) |
| `dimension_code` | VARCHAR(50) | NULL | - | - | Dimension code/abbreviation |
| `indicator_template_id` | BIGINT | NULL | - | - | FK to survey_stoplight_indicator (master template) |
| `indicator_template_code_name` | VARCHAR(255) | NULL | - | - | Template code name for lineage tracking |

#### Valid Dimension Names
- "Education and Culture"
- "Health and Environment"
- "Housing and Infrastructure"
- "Income and Employment"
- "Interiority and Motivation"
- "Organization and Participation"

#### Indexes

```sql
CREATE UNIQUE INDEX idx_indicator_pk ON dim_indicator (indicator_key);
CREATE UNIQUE INDEX idx_indicator_natural_key ON dim_indicator (indicator_id);
CREATE INDEX idx_indicator_code ON dim_indicator (indicator_code_name);
CREATE INDEX idx_indicator_dimension ON dim_indicator (dimension_id);
CREATE INDEX idx_indicator_dim_name ON dim_indicator (dimension_name);
CREATE INDEX idx_indicator_template ON dim_indicator (indicator_template_id);
```

#### Source Mapping

| Target Column | Source Table | Source Column | Transformation |
|---------------|--------------|---------------|----------------|
| `indicator_id` | data_collect.survey_stoplight | id | Direct mapping |
| `indicator_code_name` | data_collect.survey_stoplight | code_name | Direct mapping |
| `indicator_short_name` | data_collect.survey_stoplight | short_name | Direct mapping |
| `dimension_name` | data_collect.survey_stoplight | dimension | Direct mapping |
| `indicator_template_id` | data_collect.survey_stoplight | survey_stoplight_indicator_id | Direct mapping |

---

### dim_family

**Description:** Family identity and geography

**Grain:** One row per family

**Row Count:** ~3,000-10,000 families

---

#### Column Specifications

| Column Name | Data Type | Nullable | Default | Constraints | Description |
|-------------|-----------|----------|---------|-------------|-------------|
| `family_key` | BIGINT | NOT NULL | - | PRIMARY KEY | Surrogate key |
| `family_id` | BIGINT | NOT NULL | - | UNIQUE | Natural key from ps_families.family.family_id |
| `family_code` | VARCHAR(255) | NOT NULL | - | UNIQUE | Unique family code |
| `family_name` | VARCHAR(300) | NULL | - | - | Family name (shows 'ANON_DATA' if anonymous) |
| `family_is_active` | BOOLEAN | NOT NULL | TRUE | - | Current active status |
| `is_anonymous` | BOOLEAN | NOT NULL | FALSE | - | Whether family data is anonymized |
| `country` | VARCHAR(100) | NULL | - | - | Country name |
| `country_code` | VARCHAR(10) | NULL | - | INDEX | ISO country code (derived from birth_country) |
| `latitude` | DECIMAL(10,7) | NULL | - | CHECK (-90 to 90) | GPS latitude coordinate |
| `longitude` | DECIMAL(10,7) | NULL | - | CHECK (-180 to 180) | GPS longitude coordinate |
| `address` | VARCHAR(200) | NULL | - | - | Physical address |
| `post_code` | VARCHAR(50) | NULL | - | - | Postal code |

#### Indexes

```sql
CREATE UNIQUE INDEX idx_family_pk ON dim_family (family_key);
CREATE UNIQUE INDEX idx_family_natural_key ON dim_family (family_id);
CREATE UNIQUE INDEX idx_family_code ON dim_family (family_code);
CREATE INDEX idx_family_country ON dim_family (country_code);
CREATE INDEX idx_family_location ON dim_family (latitude, longitude) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
CREATE INDEX idx_family_anonymous ON dim_family (is_anonymous);
```

#### Source Mapping

| Target Column | Source Table | Source Column | Transformation |
|---------------|--------------|---------------|----------------|
| `family_id` | ps_families.family | family_id | Direct mapping |
| `family_code` | ps_families.family | code | Direct mapping |
| `family_name` | ps_families.family | name | Direct mapping (may be 'ANON_DATA') |
| `is_anonymous` | ps_families.family | anonymous | Direct mapping |
| `latitude` | ps_families.family | latitude | Cast to DECIMAL |
| `longitude` | ps_families.family | longitude | Cast to DECIMAL |
| `country_code` | ps_families.family_members | birth_country | Derive from first family member |

---

### dim_survey_definition

**Description:** Survey template/definition

**Grain:** One row per survey definition

**Row Count:** ~20-50 survey definitions

---

#### Column Specifications

| Column Name | Data Type | Nullable | Default | Constraints | Description |
|-------------|-----------|----------|---------|-------------|-------------|
| `survey_definition_key` | BIGINT | NOT NULL | - | PRIMARY KEY | Surrogate key |
| `survey_definition_id` | BIGINT | NOT NULL | - | UNIQUE | Natural key from data_collect.survey_definition.id |
| `survey_code` | VARCHAR(255) | NULL | - | INDEX | Unique survey code |
| `survey_title` | VARCHAR(255) | NOT NULL | - | - | Survey title |
| `survey_description` | VARCHAR(255) | NULL | - | - | Survey description |
| `survey_language` | VARCHAR(50) | NULL | - | - | Survey language code (e.g., 'en', 'es') |
| `survey_country_code` | VARCHAR(10) | NULL | - | - | Country code for survey |
| `survey_is_active` | BOOLEAN | NOT NULL | TRUE | - | Current active status |
| `survey_status` | VARCHAR(50) | NULL | - | - | Survey status (draft, active, archived) |
| `survey_is_current` | BOOLEAN | NULL | FALSE | - | If this is the current/latest version |

#### Indexes

```sql
CREATE UNIQUE INDEX idx_survey_def_pk ON dim_survey_definition (survey_definition_key);
CREATE UNIQUE INDEX idx_survey_def_natural_key ON dim_survey_definition (survey_definition_id);
CREATE INDEX idx_survey_def_code ON dim_survey_definition (survey_code);
CREATE INDEX idx_survey_def_status ON dim_survey_definition (survey_status, survey_is_active);
```

#### Source Mapping

| Target Column | Source Table | Source Column | Transformation |
|---------------|--------------|---------------|----------------|
| `survey_definition_id` | data_collect.survey_definition | id | Direct mapping |
| `survey_code` | data_collect.survey_definition | survey_code | Direct mapping |
| `survey_title` | data_collect.survey_definition | title | Direct mapping |
| `survey_language` | data_collect.survey_definition | lang | Direct mapping |
| `survey_is_active` | data_collect.survey_definition | active | Direct mapping |

---

## Special Considerations

### Data Type Choices

**BIGINT vs INTEGER:**
- Use BIGINT for natural keys from source (could grow large)
- Use INTEGER for date_key (sufficient for YYYYMMDD format)
- Use SMALLINT for small enumerated values (snapshot_number, indicator_status_value)

**VARCHAR Sizing:**
- Based on actual source data column sizes
- Allow for reasonable growth
- Can be adjusted based on data profiling

**DECIMAL for Coordinates:**
- DECIMAL(10,7) provides ~1 cm precision for GPS coordinates
- Sufficient for mapping and geographic analysis

### NULL Handling

**Fact Table:**
- Foreign keys: NOT NULL (referential integrity required)
- Measures: NULL allowed (indicator_status_value can be NULL for skipped indicators)
- Degenerate dimensions: NOT NULL (always have values)

**Dimension Tables:**
- Natural keys: NOT NULL (required for uniqueness)
- Descriptive attributes: NULL allowed (data may be incomplete)

### Index Strategy

**Primary Keys:** Clustered index on surrogate key
**Foreign Keys:** Non-clustered indexes for join performance
**Filter Columns:** Indexes on commonly filtered attributes (is_last, country_code, etc.)
**Partial Indexes:** For selective queries (e.g., is_last = TRUE)

---

## Data Quality Rules

### Fact Table Validation

1. **Referential Integrity:** All foreign keys must exist in dimension tables
2. **Value Constraints:** indicator_status_value IN (1, 2, 3, NULL)
3. **Snapshot Number:** Must be > 0
4. **Natural Key Uniqueness:** (snapshot_id, indicator_key) must be unique

### Dimension Table Validation

1. **Natural Key Uniqueness:** Each natural key must be unique
2. **Required Attributes:** NOT NULL columns must have values
3. **Hierarchy Consistency:** Child records must have valid parent records

### Cross-Table Validation

1. **Fact-Dimension Consistency:** All dimension keys in fact table must exist in dimension tables
2. **Date Range:** snapshot dates should be within reasonable range (2018-present)
3. **Geographic Validity:** Latitude (-90 to 90), Longitude (-180 to 180)
