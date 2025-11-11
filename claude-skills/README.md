# Claude Skills for PSP Data Build

This directory contains custom Claude Code skills specifically designed for working with dbt and the Poverty Stoplight data warehouse project.

## Overview

These skills extend Claude Code's capabilities with specialized knowledge for:
- **dbt-model-builder**: Creating and managing dbt models, sources, and documentation
- **metricflow-builder**: Building semantic layer components with dbt's MetricFlow

## Skills Available

### 1. dbt-model-builder
**Purpose**: Core dbt development workflows for data transformation projects

**Capabilities**:
- Define sources in `_sources.yml`
- Create staging models (cleaning and standardizing raw data)
- Create fact models (event-based or transactional data)
- Create dimension models (reference and lookup tables)
- Add schema documentation and tests
- Update existing models
- Configure model materialization and properties
- Create custom macros
- Generate and serve dbt documentation

**When to use**: When creating new dbt models, adding tests, updating model configurations, or generating documentation.

### 2. metricflow-builder
**Purpose**: Build semantic layer components using dbt's MetricFlow

**Capabilities**:
- Define semantic models (connect to dbt models with entities, dimensions, measures)
- Configure entities (join keys for automatic cross-model joins)
- Create dimensions (categorical and time dimensions for grouping/filtering)
- Define measures (aggregation building blocks: sum, count, average, etc.)
- Build metrics (simple, ratio, and derived metrics)
- Set up time spine models (for date-based analysis with daily/weekly/monthly granularity)
- Organize semantic layer files (dedicated subfolder structure)
- Test and query metrics (CLI commands for validation and testing)

**When to use**: After your dbt models are built and you need to create a semantic layer for business metrics and BI tools.

## Prerequisites

- **Claude Code**: You must be using Claude Code (claude.ai/code or the CLI)
- **Skills Feature**: Skills must be enabled in your Claude Code environment
- **Project Context**: This project uses:
  - dbt Core 1.8+
  - PostgreSQL database (Neon)
  - Python 3.8+ with uv package manager
  - Star schema data warehouse design

## Installation

### Option 1: Install via Claude Code UI (Recommended)

1. Open Claude Code
2. Navigate to Settings → Skills
3. Click "Import Skill"
4. Select the skill zip file from this directory:
   - `dbt-model-builder.zip`
   - `metricflow-builder.zip`
5. Confirm installation
6. The skill is now available for use

### Option 2: Install via Command Line

If you're using the Claude Code CLI or have direct file system access:

```bash
# Navigate to your Claude skills directory
cd ~/.claude/skills

# Copy the skill zip file
cp /path/to/psp-data-build/claude-skills/dbt-model-builder.zip .
cp /path/to/psp-data-build/claude-skills/metricflow-builder.zip .

# Extract the skills (Claude will auto-load them)
unzip dbt-model-builder.zip
unzip metricflow-builder.zip
```

### Option 3: Manual Installation

1. Download the skill zip files from this directory
2. Unzip them locally
3. Place the unzipped skill directories in your Claude Code skills directory:
   - macOS/Linux: `~/.claude/skills/`
   - Windows: `%USERPROFILE%\.claude\skills\`

## Verification

To verify the skills are installed correctly:

1. Open Claude Code
2. Type a relevant request like:
   - "Create a new staging model for the orders table"
   - "Build a semantic model for my fact table"
3. Claude should automatically invoke the appropriate skill

Alternatively, check Settings → Skills to see installed skills listed.

## Usage Guide

### Using dbt-model-builder

**Creating a Staging Model:**
```
Create a staging model for the ps_families.family table that cleans and
standardizes the raw family data
```

**Creating a Fact Model:**
```
Create a fact model called fct_family_indicator_snapshot that combines
snapshot, indicator, and survey data
```

**Adding Tests:**
```
Add data tests to the stg_snapshots model - test that id is unique and
not null, and that family_id has a relationship to stg_families
```

**Generating Documentation:**
```
Generate and serve the dbt documentation
```

### Using metricflow-builder

**Creating a Semantic Model:**
```
Create a semantic model for my fct_orders table with customer and product
as foreign entities, and measures for revenue and order count
```

**Building Metrics:**
```
Create a ratio metric for conversion rate (purchases / visitors) and a
derived metric for average order value
```

**Setting Up Time Spine:**
```
Set up a time spine model with daily, weekly, and monthly granularity
starting from 2020
```

**Testing Metrics:**
```
Show me how to test my total_revenue metric grouped by order_date using
the MetricFlow CLI
```

## Skill Development Workflow

These skills follow a **general-purpose design pattern**:
- ✅ Generic workflows and best practices
- ✅ Templates for common patterns
- ✅ Reference to project-specific docs when needed
- ❌ No hardcoded project-specific logic

This means:
- Skills provide **how** to do things (process, patterns, best practices)
- Project docs (SCHEMA_REFERENCE.md, BUSINESS_QUESTIONS_DOCS.md) provide **what** to build (context)
- You get reusable skills that work across projects, with access to this project's specifics when needed

## Skill Contents

Each skill package includes:

### SKILL.md
Main skill instructions that Claude Code loads when the skill is invoked. Contains:
- Core capabilities (step-by-step guidance)
- Code examples and templates
- Best practices
- Resources references

### references/
Documentation and guides that provide deeper context:
- Best practices documents
- Project-specific references (schema, business questions)
- Patterns and standards

### assets/
Template files ready to use:
- SQL model templates (staging, fact, dimension)
- YAML configuration templates (sources, schema, metrics)
- Folder structure guides

## Updating Skills

If the skills are updated:

1. **Backup your changes** (if you've customized the skills locally)
2. **Remove old versions** from `~/.claude/skills/`
3. **Install new versions** using the methods above
4. **Restart Claude Code** to pick up changes

## Troubleshooting

**Skill not appearing:**
- Ensure you've installed it in the correct directory
- Restart Claude Code after installation
- Check Settings → Skills to see if it's listed

**Skill not being invoked:**
- Make your request more specific (mention "create a staging model" vs just "help me")
- Explicitly mention dbt or MetricFlow in your request
- Skills are triggered by context - ensure your request matches the skill description

**Skill produces unexpected results:**
- Remember: skills provide general guidance, not project-specific hardcoded logic
- Reference the project documentation (SCHEMA_REFERENCE.md, BUSINESS_QUESTIONS_DOCS.md) when needed
- Provide more context in your request

## Contributing

These skills are maintained as part of the PSP Data Build project. To suggest improvements:

1. Test your changes in a development environment
2. Update the skill source files (in `dbt-model-builder/` or `metricflow-builder/` directories)
3. Re-package the skills using the skill creator
4. Update this README if capabilities change
5. Submit your changes via pull request

## Resources

**Claude Code Documentation:**
- Skills Guide: https://docs.claude.com/en/docs/claude-code/skills
- Skill Creator: https://github.com/anthropics/anthropic-agent-skills

**dbt Documentation:**
- dbt Core: https://docs.getdbt.com/docs/core/about-the-cli
- MetricFlow: https://docs.getdbt.com/docs/build/about-metricflow

**Project Documentation:**
- README.md (project root) - Project overview and setup
- CLAUDE.md (project root) - Claude-specific project guidance
- data_model/schema_docs/SCHEMA_REFERENCE.md - Data warehouse schema
- data_model/schema_docs/BUSINESS_QUESTIONS_DOCS.md - Business questions and metrics

## Version History

**v1.0** (2024-11-06)
- Initial release of dbt-model-builder skill
- Initial release of metricflow-builder skill
- Comprehensive templates and best practices
- Project-specific references included

---

**Questions or Issues?**

If you encounter problems with these skills or have suggestions for improvements, please document them in the project's issue tracker or discuss with the team.
