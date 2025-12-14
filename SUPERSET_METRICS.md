# Superset Semantic Layer Definition for Poverty Stoplight

This document defines the metrics and calculated columns to configure in Apache Superset for the `mart_indicators` dataset.

## 1. Base Metrics (Counts)

These are the fundamental counting blocks.

| Metric Name | SQL Expression | Description |
| :--- | :--- | :--- |
| **# Families** | `SUM(family_count)` | The total number of family-indicators in the current view. |
| **# Green** | `SUM(CASE WHEN current_label = 'Green' THEN family_count ELSE 0 END)` | Count of indicators at Green level. |
| **# Yellow** | `SUM(CASE WHEN current_label = 'Yellow' THEN family_count ELSE 0 END)` | Count of indicators at Yellow level. |
| **# Red** | `SUM(CASE WHEN current_label = 'Red' THEN family_count ELSE 0 END)` | Count of indicators at Red level. |
| **# Skipped** | `SUM(CASE WHEN current_label = 'Skipped' THEN family_count ELSE 0 END)` | Count of skipped/NA indicators. |

## 2. Ratio Metrics (Percentages)

These are best for comparing groups of different sizes (e.g., comparing Organization A vs Organization B).

| Metric Name | SQL Expression | Description |
| :--- | :--- | :--- |
| **% Green** | `SUM(CASE WHEN current_label = 'Green' THEN family_count ELSE 0 END) * 1.0 / NULLIF(SUM(family_count), 0)` | Percentage of indicators that are Green. |
| **% Yellow** | `SUM(CASE WHEN current_label = 'Yellow' THEN family_count ELSE 0 END) * 1.0 / NULLIF(SUM(family_count), 0)` | Percentage of indicators that are Yellow. |
| **% Red** | `SUM(CASE WHEN current_label = 'Red' THEN family_count ELSE 0 END) * 1.0 / NULLIF(SUM(family_count), 0)` | Percentage of indicators that are Red. |

## 3. Review & Impact Metrics (Priority & Achievement)

These metrics focus on the "Action" layer—what families prioritized and what they achieved.

| Metric Name | SQL Expression | Description |
| :--- | :--- | :--- |
| **# Priorities** | `SUM(CASE WHEN is_priority THEN family_count ELSE 0 END)` | Number of indicators families flagged as a priority. |
| **# Achieved** | `SUM(CASE WHEN has_achievement THEN family_count ELSE 0 END)` | Number of indicators marked as "Achieved". |
| **Priority Success Rate** | `SUM(CASE WHEN is_priority AND current_label = 'Green' THEN family_count ELSE 0 END) * 1.0 / NULLIF(SUM(CASE WHEN is_priority THEN family_count ELSE 0 END), 0)` | Of the indicators prioritized, what % are now Green? |
| **Achievement Rate** | `SUM(CASE WHEN has_achievement THEN family_count ELSE 0 END) * 1.0 / NULLIF(SUM(CASE WHEN was_priority_in_previous THEN family_count ELSE 0 END), 0)` | Ratio of (Achievements) / (Priorities from Previous Wave). *Requires careful filtering by snapshot.* |
| **Avg Improvement Steps** | `SUM(net_change_numeric) * 1.0 / NULLIF(SUM(family_count), 0)` | Average "steps" moved (e.g., +1.0 = Red to Yellow, or Yellow to Green). |

---

## 4. Chart Configuration Guides

### A. Progress Over Time (Line Chart)
*   **X-Axis:** `snapshot_number` (or `snapshot_type` if sorted correctly)
*   **Metrics:** `% Green`, `% Yellow`, `% Red`
*   **Dimensions (Group By):** `indicator_name` (optional, for trellis/small multiples)

### B. The "Flow" of Poverty (Sankey Diagram)
Visualizes how families move between states from Baseline to Today.
*   **Source:** `baseline_label`
*   **Target:** `current_label`
*   **Metric:** `# Families`
*   **Filters:**
    *   `is_last` = `true` (Only look at the most recent snapshot for each family)
    *   `baseline_label` != 'Skipped' (Focus on valid starting points)

### C. Strategic Effectiveness (Bar Chart)
"Are we solving the problems families actually care about?"
*   **X-Axis:** `organization_name` (or `hub_name`)
*   **Metrics:** `Priority Success Rate` vs `% Green` (Global)
*   **Insight:** If `Priority Success Rate` >> `% Green`, the organization effectively helps families solve their specific chosen problems.
