# 📊 Poverty Stoplight Data Mart Specification
## Version 1.0 - Core Semantic Layer

---

## Executive Summary

This document defines three core mart tables for the Poverty Stoplight semantic layer in dbt. These marts transform raw operational data into analysis-ready tables that support poverty measurement tracking, organizational performance monitoring, and indicator effectiveness analysis.

### Key Design Principles
- **Hub-centric hierarchy**: Application (Hub) is the highest organizational level
- **Template-instance architecture**: Track both indicator templates and their survey-specific variations
- **Simplified metrics**: Pre-calculated scores and rates for easy consumption
- **Change tracking**: Built-in progression metrics for families with multiple snapshots

---

## 📋 Mart Table Specifications

### 1️⃣ **mart_global_survey_coverage**

**Purpose**: Track survey deployment and family engagement across all hubs and organizations

**Grain**: One row per organization

**Source Tables**:
- `ps_network.applications`
- `ps_network.organizations`
- `ps_families.family`
- `data_collect.snapshot`

| Column Name | Data Type | Description | Business Logic |
|------------|-----------|-------------|----------------|
| **application_id** | bigint | Hub/Application identifier | Direct from organizations |
| **application_name** | varchar | Hub name (e.g., "Hub 52 Unbound") | From applications.name |
| **organization_id** | bigint | Organization identifier | Primary key |
| **organization_name** | varchar | Organization name | From organizations.name |
| **country_code** | varchar | Country of operation | From organizations.country_code |
| **total_families** | int | Count of families served | COUNT(DISTINCT family_id) |
| **families_with_baseline** | int | Families with initial survey | COUNT(DISTINCT family_id) WHERE snapshot_number = 1 |
| **families_with_followup** | int | Families with 2+ surveys | COUNT(DISTINCT family_id) WHERE MAX(snapshot_number) > 1 |
| **followup_rate** | decimal(5,4) | Retention rate | families_with_followup / families_with_baseline |
| **total_snapshots** | int | Total surveys completed | COUNT(snapshot.id) |
| **avg_snapshots_per_family** | decimal(4,2) | Engagement depth | total_snapshots / total_families |
| **first_survey_date** | date | Earliest survey | MIN(TO_TIMESTAMP(snapshot_date/1000)) |
| **last_survey_date** | date | Most recent survey | MAX(TO_TIMESTAMP(snapshot_date/1000)) |
| **days_since_last_activity** | int | Recency indicator | CURRENT_DATE - last_survey_date |
| **avg_days_between_snapshots** | decimal(6,1) | Survey frequency | AVG(days between consecutive snapshots per family) |

---

### 2️⃣ **mart_global_indicator_catalog**

**Purpose**: Master inventory of all poverty indicators and their global performance metrics

**Grain**: One row per unique indicator template

**Source Tables**:
- `data_collect.survey_stoplight_indicator` (templates)
- `data_collect.survey_stoplight` (implementations)
- `data_collect.snapshot_stoplight` (responses)
- `data_collect.snapshot_stoplight_priority` (priorities)

| Column Name | Data Type | Description | Business Logic |
|------------|-----------|-------------|----------------|
| **indicator_code** | varchar | Unique indicator identifier | survey_stoplight_indicator.code_name |
| **indicator_short_name** | varchar | Display name | survey_stoplight_indicator.met_short_name |
| **dimension** | varchar | Category (e.g., "Income & Employment") | Via survey_dimension_id relationship |
| **hubs_using_count** | int | Number of hubs using this indicator | COUNT(DISTINCT application_id) via survey joins |
| **total_variations** | int | Customized implementations | COUNT(DISTINCT survey_stoplight.id) WHERE survey_stoplight_indicator_id matches |
| **total_responses** | int | Total measurements taken | COUNT(snapshot_stoplight) for this indicator |
| **families_measured** | int | Unique families assessed | COUNT(DISTINCT family_id) via snapshot join |
| **global_red_rate** | decimal(5,4) | Poverty rate | COUNT(value=1) / COUNT(*) |
| **global_yellow_rate** | decimal(5,4) | Vulnerability rate | COUNT(value=2) / COUNT(*) |
| **global_green_rate** | decimal(5,4) | Non-poor rate | COUNT(value=3) / COUNT(*) |
| **improvement_rate** | decimal(5,4) | % improving over time | Families whose latest value > first value / families with 2+ measurements |
| **priority_selection_rate** | decimal(5,4) | Priority frequency | COUNT(snapshot_stoplight_priority) / COUNT(snapshot_stoplight) |

---

### 3️⃣ **mart_py_family_current_state**

**Purpose**: Current poverty status and progression for each family in Paraguay

**Grain**: One row per family

**Filter**: Country-specific (Paraguay in this implementation)

**Source Tables**:
- `ps_families.family`
- `data_collect.snapshot` 
- `data_collect.snapshot_stoplight`
- `data_collect.snapshot_stoplight_priority`
- `ps_network.organizations`

| Column Name | Data Type | Description | Business Logic |
|------------|-----------|-------------|----------------|
| **family_id** | bigint | Family identifier | Primary key |
| **family_code** | varchar | Family code | From family.code |
| **organization_name** | varchar | Serving organization | From organizations.name |
| **is_anonymous** | boolean | Privacy flag | From family.anonymous |
| **first_snapshot_date** | date | Initial assessment | MIN(TO_TIMESTAMP(snapshot_date/1000)) |
| **latest_snapshot_date** | date | Most recent assessment | MAX(TO_TIMESTAMP(snapshot_date/1000)) WHERE is_last = true |
| **total_snapshots** | int | Survey count | COUNT(snapshot.id) |
| **months_since_baseline** | decimal(5,1) | Time in program | MONTHS_BETWEEN(latest_snapshot_date, first_snapshot_date) |
| **total_indicators** | int | Indicators measured | COUNT(snapshot_stoplight) for latest snapshot |
| **indicators_red** | int | Critical poverty count | COUNT(value=1) for latest snapshot |
| **indicators_yellow** | int | Moderate poverty count | COUNT(value=2) for latest snapshot |
| **indicators_green** | int | Non-poor count | COUNT(value=3) for latest snapshot |
| **poverty_score** | decimal(5,4) | Overall score (0-1) | (green×3 + yellow×2 + red×1) / (total×3) |
| **income_score** | decimal(5,4) | Dimension score (0-1) | Calculated per dimension indicators |
| **health_score** | decimal(5,4) | Dimension score (0-1) | Calculated per dimension indicators |
| **housing_score** | decimal(5,4) | Dimension score (0-1) | Calculated per dimension indicators |
| **education_score** | decimal(5,4) | Dimension score (0-1) | Calculated per dimension indicators |
| **organization_score** | decimal(5,4) | Dimension score (0-1) | Calculated per dimension indicators |
| **self_awareness_score** | decimal(5,4) | Dimension score (0-1) | Calculated per dimension indicators |
| **poverty_score_change** | decimal(5,4) | Overall change | Latest score - baseline score (NULL if only 1 snapshot) |
| **indicators_improved** | int | Improvements count | COUNT where latest value > baseline value |
| **indicators_declined** | int | Regressions count | COUNT where latest value < baseline value |
| **income_score_change** | decimal(5,4) | Dimension change | Latest - baseline (NULL if only 1 snapshot) |
| **health_score_change** | decimal(5,4) | Dimension change | Latest - baseline (NULL if only 1 snapshot) |
| **housing_score_change** | decimal(5,4) | Dimension change | Latest - baseline (NULL if only 1 snapshot) |
| **education_score_change** | decimal(5,4) | Dimension change | Latest - baseline (NULL if only 1 snapshot) |
| **organization_score_change** | decimal(5,4) | Dimension change | Latest - baseline (NULL if only 1 snapshot) |
| **self_awareness_score_change** | decimal(5,4) | Dimension change | Latest - baseline (NULL if only 1 snapshot) |
| **priorities_selected** | text[] | Priority indicator codes | ARRAY_AGG(code_name) from priorities |
| **priority_count** | int | Number of priorities | COUNT(snapshot_stoplight_priority) |

---

## 🔧 Implementation Notes

### Data Quality Considerations
1. **Anonymous handling**: When `anonymous = true`, personal fields contain 'ANON_DATA'
2. **Latest snapshot identification**: Use `is_last = true` for current family status
3. **Timestamp conversion**: Most timestamps stored as bigint milliseconds - use `TO_TIMESTAMP(field/1000)`
4. **Survey rounds**: `snapshot_number = 1` indicates baseline, >1 indicates follow-up

### Dimension Mapping
Standard six dimensions (may vary by country):
- Income & Employment
- Health & Environment  
- Housing & Infrastructure
- Education & Culture
- Organization & Participation
- Self-Awareness & Motivation