{{ config(
    materialized="view",
    tags=["mart", "fact", "semantic_layer"]
) }}

with enriched as (
    select * from {{ ref('int_snapshot_enriched') }}
),

final as (
    select
        -- Primary key
        snapshot_id,

        -- Foreign keys (dimensions)
        family_id,
        organization_id,
        application_id,
        survey_definition_id,
        project_id,

        -- Snapshot attributes
        snapshot_number,
        snapshot_ts,
        created_at_ts,

        -- Flags
        stoplight_skipped,
        anonymous,
        is_baseline,
        is_last_any,
        is_last_with_stoplight,
        is_last_original,

        -- Temporal metrics
        days_since_prev,

        -- User tracking
        created_by,
        last_modified_by,
        survey_user_id,

        -- JSON data (for future indicator extraction)
        economic,
        stoplight,

        -- Other metadata
        draft_id,
        sign,
        stoplight_client,
        lifemap_url

    from enriched
)

select * from final
