# Superset Semantic Layer Definition for Operations & Demographics

This document defines the metrics to configure in Apache Superset for the `mart_surveys` dataset (Operations & Demographics).
This model is at the **Snapshot (Survey)** grain, meaning each row represents one survey event.

## 1. Core Metrics (Counts & Operations)

There are two primary ways to count: historical volume (Workload) and current active portfolio (Reach).

| Metric Name | SQL Expression | Description |
| :--- | :--- | :--- |
| **Total Surveys (Volume)** | `COUNT(*)` | Total number of surveys ever conducted. Useful for "Work Done" reports. |
| **Total Active Families** | `COUNT(CASE WHEN is_last = TRUE THEN 1 END)` | **Key Metric.** The number of unique families currently being served. |
| **Total Baseline Surveys** | `COUNT(CASE WHEN is_baseline = TRUE THEN 1 END)` | Number of families enrolled (started). |
| **Total Follow-up Surveys** | `COUNT(CASE WHEN NOT is_baseline THEN 1 END)` | Number of follow-up visits conducted. |

## 2. Efficiency Metrics (Speed & Timing)

How fast are we moving families through the program?

| Metric Name | SQL Expression | Description |
| :--- | :--- | :--- |
| **Avg Days Between Visits** | `AVG(days_since_previous)` | On average, how many days pass between one survey and the next? |
| **Median Days Between Visits** | `MEDIAN(days_since_previous)` | (Postgres 9.4+) Better than Average for removing outliers (e.g., dropped families). |
| **Days Since Baseline** | `AVG(days_since_baseline)` | Average program duration for the cohort in view. |

## 3. Geographic & Demographic Metrics

These are often used on Map Charts or Distribution Bar Charts.

| Metric Name | SQL Expression | Description |
| :--- | :--- | :--- |
| **# Families (Map)** | `COUNT(*) WHERE is_last = TRUE` | *Filter for Map Charts.* Ensures each family appears as only one dot (their most recent location). |
| **% Anonymous** | `COUNT(CASE WHEN is_anonymous THEN 1 END) * 1.0 / COUNT(*)` | Percentage of surveys where privacy mode was enabled. |

---

## 4. Key Chart Configurations

### A. The "Where are we?" Map
*   **Visualization:** Mapbox / Deck.gl Scatterplot
*   **Longitude:** `longitude`
*   **Latitude:** `latitude`
*   **Metric:** `Total Active Families` (Filter: `is_last = true`)
*   **Color By:** `project_name` or `country_name`

### B. The "Retension Funnel" (Cohort Analysis)
"How many families make it to the 2nd and 3rd visit?"
*   **Visualization:** Bar Chart
*   **X-Axis:** `snapshot_number` (1, 2, 3...)
*   **Metric:** `Total Surveys`
*   **Insight:** Shows the drop-off rate between survey rounds.

### C. Operational Efficiency
"Which organizations move the fastest?"
*   **Visualization:** Bar Chart
*   **X-Axis:** `organization_name`
*   **Metric:** `Avg Days Between Visits`
*   **Sort:** Descending (Slowest to Fastest)
