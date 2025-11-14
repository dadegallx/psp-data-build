# Star Schema Entity Relationship Diagram
## Poverty Stoplight Data Warehouse

---

## Mermaid ERD

```mermaid
erDiagram
    %% Fact Tables
    FACT_FAMILY_INDICATOR_SNAPSHOT {
        bigint family_indicator_snapshot_key PK
        integer date_key FK
        bigint organization_key FK
        bigint indicator_key FK
        bigint family_key FK
        bigint survey_definition_key FK
        bigint snapshot_id "Degenerate Dim"
        smallint snapshot_number "Degenerate Dim"
        boolean is_last "Degenerate Dim"
        smallint indicator_status_value "MEASURE"
    }

    FACT_FAMILY_ECONOMIC_SNAPSHOT {
        bigint family_economic_snapshot_key PK
        integer date_key FK
        bigint family_key FK
        bigint economic_question_key FK
        bigint organization_key FK
        bigint survey_definition_key FK
        bigint snapshot_id "Degenerate Dim"
        smallint snapshot_number "Degenerate Dim"
        boolean is_last "Degenerate Dim"
        numeric household_monthly_income "MEASURE"
        varchar income_currency_code "MEASURE"
        varchar housing_situation_single "MEASURE"
        text housing_situation_multi "MEASURE"
        varchar activity_main_single "MEASURE"
        text activity_main_multi "MEASURE"
        text activity_main_text "MEASURE"
        boolean family_car "MEASURE"
        varchar area_of_residence_select "MEASURE"
        varchar area_of_residence_radio "MEASURE"
    }

    %% Dimension Tables
    DIM_DATE {
        integer date_key PK
        date date_actual
        varchar day_of_week
        smallint day_of_week_number
        smallint day_of_month
        smallint day_of_year
        smallint week_of_year
        smallint month_number
        varchar month_name
        varchar month_abbr
        smallint quarter_number
        varchar quarter_name
        smallint year_number
        varchar year_quarter
        varchar year_month
        boolean is_weekend
    }

    DIM_ORGANIZATION {
        bigint organization_key PK
        bigint organization_id NK
        varchar organization_name
        varchar organization_description
        boolean organization_is_active
        varchar organization_country
        varchar organization_country_code
        varchar organization_type
        bigint application_id "Hierarchy"
        varchar application_name "Hierarchy"
        varchar application_description "Hierarchy"
        boolean application_is_active "Hierarchy"
        varchar application_country "Hierarchy"
        varchar application_country_code "Hierarchy"
    }

    DIM_INDICATOR {
        bigint indicator_key PK
        bigint indicator_id NK
        varchar indicator_code_name
        varchar indicator_short_name
        varchar indicator_question_text
        text indicator_description
        boolean indicator_is_required
        bigint dimension_id "Hierarchy"
        varchar dimension_name "Hierarchy"
        varchar dimension_code "Hierarchy"
        bigint indicator_template_id
        varchar indicator_template_code_name
    }

    DIM_FAMILY {
        bigint family_key PK
        bigint family_id NK
        varchar family_code
        varchar family_name
        boolean family_is_active
        boolean is_anonymous
        varchar country
        varchar country_code
        decimal latitude
        decimal longitude
        varchar address
        varchar post_code
    }

    DIM_SURVEY_DEFINITION {
        bigint survey_definition_key PK
        bigint survey_definition_id NK
        varchar survey_code
        varchar survey_title
        varchar survey_description
        varchar survey_language
        varchar survey_country_code
        boolean survey_is_active
        varchar survey_status
        boolean survey_is_current
    }

    DIM_ECONOMIC_QUESTIONS {
        bigint economic_question_key PK
        bigint survey_definition_id NK
        varchar code_name NK
        text question_text
        varchar answer_type
        text answer_options
        varchar scope
        boolean is_for_family_member
        varchar survey_code
        varchar survey_title
        varchar survey_language
    }

    %% Relationships - Stoplight Fact
    FACT_FAMILY_INDICATOR_SNAPSHOT ||--o{ DIM_DATE : "surveyed_on"
    FACT_FAMILY_INDICATOR_SNAPSHOT ||--o{ DIM_ORGANIZATION : "conducted_by"
    FACT_FAMILY_INDICATOR_SNAPSHOT ||--o{ DIM_INDICATOR : "measures"
    FACT_FAMILY_INDICATOR_SNAPSHOT ||--o{ DIM_FAMILY : "assesses"
    FACT_FAMILY_INDICATOR_SNAPSHOT ||--o{ DIM_SURVEY_DEFINITION : "uses_template"

    %% Relationships - Economic Fact
    FACT_FAMILY_ECONOMIC_SNAPSHOT ||--o{ DIM_DATE : "surveyed_on"
    FACT_FAMILY_ECONOMIC_SNAPSHOT ||--o{ DIM_FAMILY : "assesses"
    FACT_FAMILY_ECONOMIC_SNAPSHOT ||--o{ DIM_ECONOMIC_QUESTIONS : "answers"
    FACT_FAMILY_ECONOMIC_SNAPSHOT ||--o{ DIM_ORGANIZATION : "conducted_by"
    FACT_FAMILY_ECONOMIC_SNAPSHOT ||--o{ DIM_SURVEY_DEFINITION : "uses_template"
```