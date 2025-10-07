## Database Structure

The database consists of five main schemas: `data_collect`, `library`, `ps_families`, `ps_network`, and `ps_solutions`. Each schema contains tables related to different aspects of the poverty assessment and intervention system.

### Schema: ps_network

Contains organizational hierarchy and hub/application management.

#### Table: ps_network.applications
Hub/application definitions that serve as platforms for implementing poverty stoplight projects.
- **id** (bigint): Primary key
- **name** (varchar): Application/hub name
- **description** (varchar): Application description
- **is_active** (boolean): If application is active
- **country** (varchar): Country where application operates
- **logo_url** (text[]): Array of logo URLs
- **labels** (text[]): Feature flags/labels array
- **language** (varchar): Default language
- **partner_type** (varchar): Type of partner
- **created_by** (varchar): Creator
- **last_modified_by** (varchar): Last modifier
- **created_date** (timestamp): Creation date
- **last_modified_date** (timestamp): Last modification
- **country_code** (varchar): ISO country code

#### Table: ps_network.organizations
Organizations implementing poverty stoplight surveys within applications.
- **id** (bigint): Primary key
- **name** (varchar): Organization name
- **description** (varchar): Organization description
- **is_active** (boolean): If organization is active
- **country** (varchar): Country of operation
- **information** (varchar): Additional information
- **application_id** (bigint): FK to ps_network.applications
- **logo_url** (text[]): Array of logo URLs
- **support_email** (varchar): Support contact email
- **area_expertise_type** (varchar): Area of expertise
- **final_user_type** (varchar): Target user type
- **organization_type** (varchar): Type of organization
- **end_survey_type** (varchar): Survey completion type
- **solutions_access** (varchar): Solutions access level
- **projects_access** (boolean): If has project access
- **solutions_allowed_facilitators** (boolean): If facilitators can access solutions
- **footer_text** (varchar): Custom footer text
- **created_by** (varchar): Creator
- **last_modified_by** (varchar): Last modifier
- **created_date** (timestamp): Creation date
- **last_modified_date** (timestamp): Last modification
- **solutions_crud_facilitators** (boolean): If facilitators can manage solutions
- **country_code** (varchar): ISO country code
- **projects_required** (boolean): If projects are required
- **language** (varchar): Default language
- **feature_flags** (varchar): Feature flags

### Schema: data_collect

This schema contains survey data collection, snapshot information, and related configuration tables.

#### Table: data_collect.survey_stoplight_indicator
Master template catalog of reusable stoplight indicators (346 templates).
- **id** (bigint): Primary key [NOT NULL]
- **code_name** (varchar): Unique indicator code [NOT NULL]
- **met_short_name** (varchar): Short name for indicator [NOT NULL]
- **met_description** (varchar): Description of indicator [NOT NULL]
- **survey_dimension_id** (bigint): FK to dimension [NOT NULL]

**Key Relationship**: This table serves as the template catalog that `data_collect.survey_stoplight` references via `survey_stoplight.survey_indicator_id → survey_stoplight_indicator.id`. One template can be reused across multiple surveys with customization.

#### Table: data_collect.snapshot
Main table storing survey snapshots (completed surveys).
- **id** (bigserial): Primary key
- **organization_id** (bigint): Reference to ps_network.organizations
- **application_id** (bigint): Reference to ps_network.applications
- **created_at** (bigint): Timestamp when created (milliseconds since epoch)
- **created_by** (varchar(100)): User who created
- **survey_definition_id** (bigint): FK to survey_definition
- **snapshot_date** (bigint): Date when survey was taken (milliseconds since epoch)
- **family_id** (bigint): FK to ps_families.family
- **snapshot_indicator_id** (bigint): Reference to indicator
- **terms_conditions_id** (bigint): Reference to terms
- **privacy_policy_id** (bigint): Reference to privacy policy
- **survey_user_id** (bigint): User who took survey
- **draft_id** (varchar(200)): Unique draft identifier
- **stoplight_skipped** (boolean): If stoplight section was skipped
- **sign** (varchar(200)): Signature as Base64
- **is_last** (boolean): If last snapshot for family **[KEY FOR CURRENT STATUS]**
- **economic** (jsonb): Demographic section JSON
- **stoplight** (jsonb): Stoplight section JSON
- **snapshot_number** (smallint): Survey round (1=baseline, >1=follow-up)
- **stoplight_client** (varchar(20)): Frontend client used
- **project_id** (bigint): Reference to project
- **family_user_id** (bigint): Reference to family user
- **last_taken_family** (boolean): If last taken for family
- **last_modified_by** (varchar(255)): Last modifier
- **created_date** (timestamp(0)): Creation timestamp
- **last_modified_date** (timestamp(0)): Last modification timestamp
- **session_token** (varchar(100)): Session token
- **economic_time** (bigint): Time for economic section
- **stoplight_time** (bigint): Time for stoplight section
- **lifemap_time** (bigint): Time for lifemap section
- **stoplight_date** (bigint): Stoplight completion date
- **migrated_to_central** (boolean): If migrated to central
- **lifemap_url** (text): URL to PDF lifemap in S3
- **anonymous** (boolean): If survey was anonymous **[KEY FOR PRIVACY]**

#### Table: data_collect.snapshot_draft
Stores draft survey states before completion.
- **id** (bigint): Primary key
- **state_draft** (jsonb): Draft state in JSON format
- **survey_definition_id** (bigint): FK to survey_definition

#### Table: data_collect.snapshot_economic
Economic indicators from snapshots.
- **id** (bigserial): Primary key
- **code_name** (varchar(255)): Unique indicator code
- **answer_type** (varchar(50)): Response type
- **answer_value** (varchar(1000)): Response value
- **answer_options** (text): Available options
- **answer_number** (double precision): Numeric value
- **answer_date** (bigint): Date value (milliseconds since epoch)
- **other_text** (text): Other option text
- **snapshot_id** (bigint): FK to snapshot
- **created_by** (varchar(255)): Creator
- **last_modified_by** (varchar(255)): Last modifier
- **created_date** (timestamp(0)): Creation date
- **last_modified_date** (timestamp(0)): Last modification

#### Table: data_collect.snapshot_economic_member_only
Economic data for individual family members.
- **id** (bigserial): Primary key
- **item_number** (integer): Item index (default: 0)
- **code_name** (varchar(255)): Indicator code
- **answer_type** (varchar(50)): Response type
- **answer_value** (varchar(1000)): Response value
- **answer_number** (double precision): Numeric value
- **other_text** (text): Other option text
- **answer_date** (bigint): Date value (milliseconds since epoch)
- **snapshot_id** (bigint): FK to snapshot
- **answer_options** (text): Available options
- **created_by** (varchar(255)): Creator
- **last_modified_by** (varchar(255)): Last modifier
- **created_date** (timestamp(0)): Creation date
- **last_modified_date** (timestamp(0)): Last modification
- **family_member_id** (bigint): FK to family member
- **member_identifier** (text): Member identifier

#### Table: data_collect.snapshot_stoplight
Stoplight indicator values from snapshots (20,081+ customized implementations).
- **id** (bigserial): Primary key
- **code_name** (varchar(255)): Indicator code
- **value** (integer): Indicator value (1=Red, 2=Yellow, 3=Green)
- **updated_at** (bigint): Update timestamp (milliseconds since epoch)
- **updated_by** (varchar(100)): Updater
- **snapshot_id** (bigint): FK to snapshot
- **created_by** (varchar(255)): Creator
- **last_modified_by** (varchar(255)): Last modifier
- **created_date** (timestamp(0)): Creation date
- **last_modified_date** (timestamp(0)): Last modification

#### Table: data_collect.snapshot_stoplight_priority
Priority indicators for improvement.
- **id** (bigserial): Primary key
- **reason** (text): Why not at Green level
- **action** (text): Planned action
- **estimated_date** (bigint): Months to improve
- **created_at** (bigint): Creation timestamp (milliseconds since epoch)
- **created_by** (varchar(100)): Creator
- **snapshot_stoplight_id** (bigint): FK to snapshot_stoplight
- **last_modified_by** (varchar(255)): Last modifier
- **created_date** (timestamp(0)): Creation date
- **last_modified_date** (timestamp(0)): Last modification

#### Table: data_collect.snapshot_stoplight_achievement
Achievements and roadmaps for improvements.
- **id** (bigserial): Primary key
- **action** (text): Action taken/planned
- **roadmap** (text): Steps to achieve
- **estimated_date** (bigint): Target date (milliseconds since epoch)
- **has_problems** (boolean): If has issues
- **snapshot_stoplight_id** (bigint): FK to snapshot_stoplight
- **created_at** (bigint): Creation timestamp (milliseconds since epoch)
- **created_by** (varchar(100)): Creator
- **last_modified_by** (varchar(255)): Last modifier
- **created_date** (timestamp(0)): Creation date
- **last_modified_date** (timestamp(0)): Last modification

#### Table: data_collect.snapshot_file
Files attached to snapshots.
- **id** (bigserial): Primary key
- **name** (varchar(255)): File name
- **category** (varchar(100)): File type (e.g., 'picture')
- **url** (varchar(500)): File URL in S3
- **snapshot_id** (bigint): FK to snapshot
- **created_date** (timestamp(0)): Creation date
- **last_modified_date** (timestamp(0)): Last modification

#### Table: data_collect.survey_definition
Survey configuration and metadata.
- **id** (bigserial): Primary key
- **title** (varchar(255)): Survey title
- **description** (varchar(255)): Survey description
- **active** (boolean): If survey is active
- **created_at** (timestamp(0)): Creation date
- **updated_at** (timestamp(0)): Update date
- **terms_conditions_id** (bigint): Terms reference
- **privacy_policy_id** (bigint): Privacy reference
- **minimum_priorities** (integer): Min priorities required
- **country_code** (varchar(10)): Country code
- **latitude** (varchar(50)): Survey location latitude
- **longitude** (varchar(50)): Survey location longitude
- **labels** (text[]): Feature flags array
- **lang** (varchar(50)): Survey language
- **survey_code** (varchar(255)): Unique survey code
- **stoplight_type** (varchar(50)): Stoplight type
- **status** (varchar(50)): Survey status
- **current** (boolean): If current version
- **disclaimer_required** (boolean): If disclaimer needed
- **disclaimer_text** (text): Disclaimer content
- **disclaimer_title** (text): Disclaimer title
- **disclaimer_subtitle** (text): Disclaimer subtitle

#### Table: data_collect.survey_economic
Economic questions configuration.
- **id** (bigserial): Primary key
- **code_name** (varchar(255)): Question code
- **question_text** (varchar(300)): Question text
- **description** (varchar(255)): Question details
- **topic** (varchar(100)): Question category
- **answer_type** (varchar(50)): Expected answer type
- **answer_options** (text): Available choices
- **scope** (varchar(50)): Question scope (family/individual)
- **condition_filter** (varchar(300)): Display conditions
- **created_at** (date): Creation date
- **updated_at** (date): Update date
- **for_family_member** (boolean): If for members
- **required** (boolean): If mandatory
- **survey_definition_id** (bigint): FK to survey_definition
- **order_number** (integer): Display order
- **short_name** (varchar(255)): Short name
- **topic_help** (text): Topic help text
- **topic_audio** (varchar(500)): Audio file link
- **question_help** (text): Question help
- **introduction** (varchar(350)): Introduction text
- **for_tableau** (boolean): If for Tableau

#### Table: data_collect.survey_economic_option
Options for economic questions.
- **id** (bigserial): Primary key
- **value** (varchar(100)): Option value
- **text** (varchar(500)): Option description
- **survey_economic_id** (bigint): FK to survey_economic
- **other_option** (boolean): If allows other
- **order_number** (integer): Display order

#### Table: data_collect.survey_stoplight
Stoplight questions configuration (survey-specific implementations).
- **id** (bigserial): Primary key
- **code_name** (varchar(255)): Question code
- **short_name** (varchar(255)): Short name
- **question_text** (varchar(300)): Question text
- **description** (text): Aspirational description
- **dimension** (varchar(100)): Associated dimension
- **created_at** (date): Creation date
- **updated_at** (date): Update date
- **required** (boolean): If mandatory
- **survey_definition_id** (bigint): FK to survey_definition
- **order_number** (integer): Display order
- **definition** (text): Question explanation
- **survey_stoplight_indicator_id** (bigint): FK to survey_stoplight_indicator **[TEMPLATE REFERENCE]**
- **survey_stoplight_dimension_id** (bigint): FK to dimension
- **question_help** (text): Help text
- **question_audio** (varchar(500)): Audio URL
- **reviewed** (boolean): If reviewed
- **status** (varchar(50)): Question status
- **has_na** (boolean): If has N/A option

#### Table: data_collect.survey_stoplight_color
Color level definitions for stoplight indicators.
- **id** (bigserial): Primary key
- **url** (varchar(500)): Image URL in S3
- **value** (integer): Color value (1=Red, 2=Yellow, 3=Green)
- **description** (text): Level requirements
- **created_at** (date): Creation date
- **updated_at** (date): Update date
- **survey_stoplight_id** (bigint): FK to survey_stoplight

### Schema: library

Contains reference data for stoplight indicators.

#### Table: library.stoplight_indicator
Master list of stoplight indicators.
- **id** (bigserial): Primary key
- **code_name** (varchar(255)): Unique code [REQUIRED]
- **short_name** (varchar(255)): Short name [REQUIRED]
- **question_text** (varchar(300)): Question text [REQUIRED]
- **definition** (text): Detailed explanation
- **status** (varchar(300)): Current status [REQUIRED]
- **lang** (varchar(255)): Language code
- **country** (varchar(255)): Country
- **measurement_unit** (varchar(255)): Unit of measure
- **tag** (varchar(255)): Classification tags
- **zones** (text[]): Stoplight zones array
- **targets** (text[]): Targets array
- **stoplight_dimension_id** (bigint): FK to dimension
- **verified** (boolean): If verified (default: false)
- **description** (varchar(255)): Life Map name
- **stoplight_type** (varchar(50)): Indicator type
- **created_at** (timestamp(0)): Creation date
- **created_by** (varchar(50)): Creator
- **updated_at** (timestamp(0)): Update date
- **updated_by** (varchar(50)): Updater
- **dynamo_id** (varchar(255)): DynamoDB ID [UNIQUE]
- **generic** (boolean): If generic (default: false)

### Schema: ps_families

Contains family and member information.

#### Table: ps_families.family
Main family records.
- **family_id** (bigserial): Primary key
- **name** (varchar(300)): Family name ('ANON_DATA' if anonymous) **[PRIVACY INDICATOR]**
- **country** (bigint): FK to system.countries
- **application_id** (bigint): FK to ps_network.applications
- **organization_id** (bigint): FK to ps_network.organizations
- **code** (varchar(255)): Unique family code [REQUIRED]
- **is_active** (boolean): If active (default: true)
- **last_modified_at** (timestamp with time zone): Last modification
- **user_id** (bigint): FK to security.users (mentor)
- **count_family_members** (bigint): Member count
- **longitude** (varchar(200)): Location longitude
- **latitude** (varchar(200)): Location latitude
- **accuracy** (varchar(200)): GPS accuracy
- **address** (varchar(200)): Physical address
- **post_code** (text): Postal code
- **lifemap_url** (varchar(500)): LifeMap URL
- **project_id** (bigint): FK to ps_network.projects
- **family_user_id** (bigint): FK to security.users
- **profile_picture_url** (varchar(200)): Profile picture
- **created_by** (varchar(255)): Creator
- **last_modified_by** (varchar(255)): Last modifier
- **created_date** (timestamp(0)): Creation date
- **last_modified_date** (timestamp(0)): Last modification
- **legacy_family_code** (varchar(255)): Previous system ID
- **anonymous** (boolean): If anonymous survey **[PRIVACY INDICATOR]**

#### Table: ps_families.family_members
Individual family member records.
- **id** (bigint): Primary key
- **first_name** (varchar(150)): First name ('ANON_DATA' if anonymous) [REQUIRED] **[PRIVACY INDICATOR]**
- **last_name** (varchar(150)): Last name ('ANON_DATA' if anonymous) **[PRIVACY INDICATOR]**
- **gender** (varchar(100)): Gender code ('ANON_DATA' if anonymous) **[PRIVACY INDICATOR]**
- **gender_text** (text): Gender display text
- **birth_date** (bigint): Birth timestamp (milliseconds since epoch)
- **document_type** (varchar(100)): Document type code
- **document_type_text** (text): Document type display
- **document_number** (varchar(100)): Document number
- **birth_country** (varchar(150)): Birth country
- **email** (varchar(120)): Email address
- **phone_number** (varchar(120)): Phone number
- **family_id** (bigint): FK to ps_families.family [REQUIRED]
- **first_participant** (boolean): If first participant
- **member_identifier** (text): Custom identifier
- **date_of_birth** (date): Birth date
- **custom_document_type** (text): Custom document type
- **custom_gender** (text): Custom gender
- **active** (boolean): If active
- **snapshot_id** (bigint): FK to data_collect.snapshot
- **phone_code** (varchar(500)): Phone country code
- **created_by** (varchar(255)): Creator
- **last_modified_by** (varchar(255)): Last modifier
- **created_date** (timestamp(0)): Creation date
- **last_modified_date** (timestamp(0)): Last modification
- **anonymous** (boolean): If anonymous (default: false) **[PRIVACY INDICATOR]**

#### Table: ps_families.family_details
Additional family information.
- **id** (bigserial): Primary key
- **family_id** (bigint): FK to ps_families.family [REQUIRED]
- **snapshot_id** (bigint): FK to data_collect.snapshot
- **count_family_members** (bigint): Member count
- **longitude** (varchar(200)): Location longitude
- **latitude** (varchar(200)): Location latitude
- **address** (varchar(200)): Physical address
- **post_code** (text): Postal code
- **created_by** (varchar(255)): Creator
- **last_modified_by** (varchar(255)): Last modifier
- **created_date** (timestamp(0)): Creation date
- **last_modified_date** (timestamp(0)): Last modification

#### Table: ps_families.family_notes
Notes and observations about families.
- **id** (bigserial): Primary key
- **note** (text): Note content [REQUIRED]
- **note_type** (varchar(255)): Note type (deprecated)
- **note_date** (bigint): Note timestamp [REQUIRED] (milliseconds since epoch)
- **note_user** (varchar(255)): Note creator [REQUIRED]
- **family_id** (bigint): FK to ps_families.family [REQUIRED]
- **created_by** (varchar(255)): Creator
- **last_modified_by** (varchar(255)): Last modifier
- **created_date** (timestamp(0)): Creation date
- **last_modified_date** (timestamp(0)): Last modification

### Schema: ps_solutions

Contains intervention solutions.

#### Table: ps_solutions.solution
Solutions for poverty indicators.
- **id** (bigserial): Primary key
- **code_name** (varchar(255)): Solution code
- **title** (varchar(255)): Solution title [REQUIRED]
- **description** (varchar(1000)): Brief description
- **content_text** (text): Full text content [REQUIRED]
- **content_rich** (text): Rich text content [REQUIRED]
- **dimension** (varchar(100)): Solution category
- **indicators_code_names** (text[]): Related indicator codes
- **indicators_names** (text[]): Related indicator names
- **further_references** (text[]): Additional references
- **contact_info** (text): Contact information
- **country** (varchar(10)): Country code
- **lang** (varchar(10)): Language code
- **show_author** (boolean): Display author [REQUIRED]
- **version** (smallint): Version number
- **state** (varchar(255)): Current state
- **created_at** (timestamp(0)): Creation date [REQUIRED]
- **created_by** (varchar(255)): Creator [REQUIRED]
- **updated_at** (timestamp(0)): Update date
- **updated_by** (varchar(255)): Updater
- **survey_stoplight_dimension_id** (bigint): FK to dimension
- **application_id** (bigint): FK to ps_network.applications
- **organization_id** (bigint): FK to ps_network.organizations
- **type** (varchar(100)): Solution type (INDIVIDUAL/COMMUNITY)
- **views** (bigint): View count
- **stakeholder_id** (bigint): FK to stakeholders
- **stoplight_type** (varchar(100)): Stoplight type
- **dimensions_names** (text[]): Dimension names
- **stoplight_types** (text[]): Associated stoplight types

## Key Relationships & Data Patterns

### Template-Instance Architecture
- **survey_stoplight_indicator**: Master template catalog (346 reusable indicator templates)
- **survey_stoplight**: Survey-specific implementations (20,081+ records, customized per survey)
- **Relationship**: `survey_stoplight.survey_stoplight_indicator_id → survey_stoplight_indicator.id`
- **Pattern**: One template can be used by multiple surveys with customization

### Organizational Hierarchy
- **Applications** (`ps_network.applications`): Hub/platform definitions (e.g., "Hub 52 Unbound")
- **Organizations** (`ps_network.organizations`): Implementing organizations within applications
- **Families** (`ps_families.family`): End beneficiaries served by organizations
- **Key Insight**: Organizations can exist without families (e.g., Organization 323 "Kuxtal Org")

### Privacy & Anonymization Patterns
- **Anonymous Flag**: When `anonymous=true`, personal data appears as 'ANON_DATA'
- **Affected Fields**: `name`, `first_name`, `last_name`, `gender` show 'ANON_DATA' when anonymous
- **Privacy Indicators**: Look for `anonymous` boolean fields across tables

### Survey Progression & Engagement
- **Current Status**: Use `is_last=true` to identify most recent family surveys
- **Survey Rounds**: `snapshot_number = 1` for baseline, `>1` for follow-ups
- **Engagement Reality**: Follow-up rates typically very low (0-9% range)
- **Data Quality**: Expect significant survey dropout between baseline and follow-up