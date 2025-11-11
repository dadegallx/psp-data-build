# Business Questions, Metrics, and Dimensions
## Poverty Stoplight Data Analysis Framework

## Business Questions

### 1. Poverty Status Analysis

**Overall Status Assessment**
1. What is the overall poverty status across all dimensions for families in the program?
2. Which poverty dimensions show the highest need (most red and yellow indicators)?
3. What is the distribution of poverty status (green/yellow/red/skipped) for each dimension?

**Indicator-Level Assessment**
4. Which specific indicators have the most critical needs (highest red counts)?
5. Which specific indicators have the most vulnerability (highest yellow counts)?
6. What is the complete status distribution for each individual indicator?
7. How do indicator results vary when sorted by different criteria (all indicators, most red+yellow, etc.)?

### 2. Geographic Analysis

8. Where are families geographically located?
9. What is the poverty status for families in specific geographic areas?
10. For a specific indicator, how does poverty status vary across different locations?
11. Which geographic areas show the highest concentration of critical needs?

### 3. Progress & Change Analysis

**Survey Progression**
12. How have families progressed between baseline and follow-up surveys?
13. Which indicators showed the most improvement (largest increase in green percentage)?
14. Which indicators showed the most deterioration (largest increase in red percentage)?
15. What are the overall poverty KPIs for each survey round (baseline vs follow-up)?

**Engagement Tracking**
16. How many families have completed multiple surveys?
17. What is the distribution of families by number of surveys completed?

### 4. Time-Based & Cohort Analysis

18. How does poverty status vary across different time periods?
19. What were the poverty levels for families surveyed within a specific date range?
20. How do cohorts of families (grouped by survey date) compare in their poverty status?

---

## Metrics

### Family-Indicator-Snapshot Level Metrics
*These metrics are calculated at the most granular level: one row per family, per indicator, per snapshot*

**Status Distribution Counts**
- Number of Green Indicators
- Number of Yellow Indicators
- Number of Red Indicators
- Number of Skipped Indicators
- Total Number of Indicators Assessed

**Status Distribution Percentages**
- Percentage Green Indicators (% of indicators at green status)
- Percentage Yellow Indicators (% of indicators at yellow status)
- Percentage Red Indicators (% of indicators at red status)
- Percentage Skipped Indicators (% of indicators skipped/not answered)

### Family-Snapshot Level Metrics
*These metrics are calculated by aggregating all indicators for a family at a specific snapshot*

**Status Distribution Counts**
- Number of Green Indicators per Family
- Number of Yellow Indicators per Family
- Number of Red Indicators per Family
- Number of Skipped Indicators per Family
- Total Number of Indicators Assessed per Family

**Status Distribution Percentages**
- Percentage Green Indicators per Family
- Percentage Yellow Indicators per Family
- Percentage Red Indicators per Family
- Percentage Skipped Indicators per Family

### Progress & Change Metrics
*These metrics compare two snapshots for the same family (typically baseline vs follow-up)*

**Status Change (Percentage Points)**
- Change in Green Percentage (percentage point difference between surveys)
- Change in Yellow Percentage (percentage point difference between surveys)
- Change in Red Percentage (percentage point difference between surveys)
- Change in Skipped Percentage (percentage point difference between surveys)

**Example**: If Survey 1 had 65% green and Survey 2 had 72% green, the change = +7 percentage points

### Volume & Engagement Metrics
*These metrics track survey participation and data volume*

**Family & Survey Counts**
- Total Number of Families
- Total Number of Surveys/Snapshots
- Number of Surveys per Family
- Number of Families with 1 Survey Only (baseline only)
- Number of Families with 2+ Surveys (baseline + follow-ups)
- Number of Families with Exactly 2 Surveys
- Number of Families with 3+ Surveys

**Indicator Counts**
- Total Number of Indicators in Survey Definition
- Total Number of Indicator Responses (across all families and surveys)

### Geographic Metrics
*These metrics support geographic/spatial analysis*

- Number of Families by Location
- Number of Surveys by Location
- Status Distribution by Location (green/yellow/red counts or percentages by area)

---

## Dimensions (Slice By)

### Organizational Hierarchy Dimensions
- **Application/Hub**: The platform or hub hosting the poverty tracking system (e.g., "Hub 52 Unbound")
- **Organization**: The implementing organization within the application conducting surveys

### Geographic Dimensions
- **Country**: Country of birth for families
- **GPS Coordinates**: Latitude and longitude for mapping family locations
- **Geographic Region**: Any regional grouping within countries

### Survey & Assessment Dimensions
- **Survey Definition**: Which survey template was used (different organizations may use different survey templates)
- **Survey Date**: The date when the survey was conducted
- **Survey Date Range**: A date range filter for analyzing surveys within specific periods
- **Snapshot Number**: Sequential survey number for each family (1 = baseline, 2 = first follow-up, 3 = second follow-up, etc.)
- **Current Status Filter**: Filter to show only most recent surveys (is_last = true) vs all surveys

### Indicator Hierarchy Dimensions
**Dimension (Category Level)**: The 6 main poverty dimensions
  - Education and Culture
  - Health and Environment
  - Housing and Infrastructure
  - Income and Employment
  - Interiority and Motivation
  - Organization and Participation

**Indicator (Specific Level)**: Individual indicators within each dimension (e.g., "Access to Credit", "Insurance", "Savings", "Varied Income", etc.)

### Status Dimensions
- **Stoplight Color**: The poverty status color for each indicator
  - Red (1): Critical poverty/need
  - Yellow (2): Moderate poverty/vulnerability
  - Green (3): Non-poor/adequate
  - Skipped: Not answered/not applicable

### Data Quality & Privacy Dimensions
- **Anonymization Status**: Whether the family data is anonymized or identified
  - Anonymous: Personal data shows as 'ANON_DATA'
  - Identified: Personal data is visible

### Cohort Dimensions
- **Survey Date Cohorts**: Groups of families based on when they were surveyed (e.g., "Q1 2024", "Jan-Mar 2024")
- **Survey Completion Cohorts**: Groups based on survey participation level
  - Baseline Only (1 survey)
  - Has Follow-up (2+ surveys)
  - Active in Follow-up (has surveys in recent period)

---

## Special Notes / Business Rules

**Current Status Analysis**: Use `is_last = true` filter to show only the most recent survey for each family

**Progress Analysis**: Compare snapshots with `snapshot_number = 1` (baseline) vs `snapshot_number > 1` (follow-ups)

**Sorting Logic for "Most Red and Most Yellow"**: Results are sorted first by red count (descending), then by yellow count (descending) - this is a two-level sort, not a sum of red+yellow
