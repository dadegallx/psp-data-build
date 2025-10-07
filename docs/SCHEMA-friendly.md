# Poverty Stoplight Database - Simplified Overview

## What This Database Does

This database tracks poverty assessments and interventions using the "Stoplight" methodology, where families self-assess their wellbeing across multiple indicators using a traffic light system (Red = critical need, Yellow = moderate, Green = doing well).

## Core Structure

### 📊 The Organizational Hierarchy

**Applications** → **Organizations** → **Families**

- **Applications** are platforms or hubs (like "Hub 52 Unbound") that host the poverty tracking system
- **Organizations** are the groups implementing surveys within these platforms
- **Families** are the beneficiaries being served and assessed
- Each level connects to the one above it, creating a clear organizational tree

### 👨‍👩‍👧‍👦 Family Information

**Families Table**
- Basic family info: name, location (GPS coordinates), unique family code
- Links to their assigned mentor/facilitator and organization
- **Privacy feature**: `anonymous` flag - when true, personal data shows as 'ANON_DATA'

**Family Members Table**
- Individual people within each family
- Personal details: names, birth dates, gender, documents
- Also respects the anonymization flag
- Links each person to their family

**Family Notes**
- Observations and updates about families over time
- Who wrote the note and when

### 📋 The Survey System

**Survey Definitions**
- Templates that define what questions to ask
- Each survey has a language, country, status
- Contains both economic questions (demographics) and stoplight questions (poverty indicators)

**Snapshots** (The Core Survey Data)
- Each completed survey creates a "snapshot" of a family's situation at that moment
- Contains economic data (income, household info) and stoplight assessments
- **Key fields for analysis**:
  - `is_last`: identifies the most recent survey for each family
  - `snapshot_number`: 1 = baseline survey, 2+ = follow-up surveys
  - `anonymous`: whether this survey was conducted anonymously
  - Timestamps for when the survey was taken

**Economic Questions**
- Demographic and socioeconomic data (income, education, housing, etc.)
- Can be about the whole family or individual members
- Stored both in the snapshot and in detailed answer tables

**Stoplight Indicators**
- The poverty measurements using the traffic light system
- Each indicator gets a color: 1=Red, 2=Yellow, 3=Green
- Families can mark priorities (indicators they want to improve)
- Can track achievements and action plans

### 🎯 The Template-Instance Pattern

**Stoplight Indicator Templates** (346 templates)
- Master catalog of reusable poverty indicators
- Examples: "Quality of clothing," "Access to clean water," "Job stability"
- Each template has a code name and belongs to a dimension

**Survey Stoplight Questions** (20,000+ implementations)
- Each survey customizes templates for their specific context
- One template can be used by many different surveys
- Each implementation may adjust the wording or requirements
- Links back to the original template

**Why This Matters**: Organizations can use proven indicators while adapting them to local contexts

### 🎨 Dimensions (Categories)

Stoplight indicators are grouped into dimensions like:
- Income & Employment
- Health & Environment  
- Housing & Infrastructure
- Education & Culture
- Organization & Participation
- Interiority & Motivation

### 💡 Solutions & Interventions

**Solutions Table**
- Resources, guides, and interventions to help families improve indicators
- Each solution targets specific indicators
- Can be individual (for one family) or community-wide
- Contains rich text content with instructions, references, contact info

## Key Data Patterns to Understand

### Time & Survey Progression
- **Baseline surveys** (`snapshot_number = 1`): First assessment of a family
- **Follow-up surveys** (`snapshot_number > 1`): Subsequent assessments to track progress
- **Reality check**: Follow-up rates are typically very low (0-9%) - many families only have baseline data

### Privacy & Anonymization
- Some surveys are conducted anonymously for sensitive populations
- When `anonymous = true`, you'll see 'ANON_DATA' instead of real names
- This applies to family names, member names, and personal identifiers

### Timestamps
- Most dates are stored as milliseconds since epoch (big numbers)
- Convert these for human-readable dates in queries

### Active vs Inactive
- Organizations and families have an `is_active` flag
- Inactive records are historical/closed
- Some organizations exist without any families (not yet active or concluded)

## How to Think About Queries

### For Current Status
Use `is_last = true` on snapshots to get each family's most recent assessment

### For Progress Over Time
Compare snapshots with different `snapshot_number` values for the same family

### For Geographic Analysis
Use application/organization country codes and family GPS coordinates

### For Indicator Analysis
Join snapshots to stoplight data, use the color values (1/2/3) for poverty levels

### For Privacy-Conscious Queries
Check the `anonymous` flag before assuming you have real names

## The Big Picture

This database captures:
1. **Who** is being served (families, through organizations and applications)
2. **What** is being measured (poverty indicators across multiple dimensions)
3. **When** assessments happened (snapshot timeline)
4. **How they're doing** (stoplight colors showing poverty levels)
5. **What can help** (solutions matched to indicators)

The system is designed to track poverty reduction over time, enable data-driven interventions, and respect beneficiary privacy while collecting meaningful data for analysis.