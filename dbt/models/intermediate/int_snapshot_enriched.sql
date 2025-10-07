{{ config(
    materialized="view",
    tags=["intermediate", "snapshot"]
) }}

with base_snapshot as (
    select
        snapshot_id,
        family_id,
        organization_id,
        application_id,
        survey_definition_id,
        project_id,
        snapshot_number,
        snapshot_ts,
        created_at_ts,
        stoplight_skipped,
        anonymous,
        created_by,
        last_modified_by,
        survey_user_id,
        economic,
        stoplight,
        draft_id,
        sign,
        stoplight_client,
        lifemap_url,
        is_last as is_last_original
    from {{ ref('stg_snapshot') }}
),

with_window_calcs as (
    select
        s.*,

        -- Derived: is this a baseline snapshot?
        (snapshot_number = 1) as is_baseline,

        -- Rank all snapshots by family (most recent = 1)
        row_number() over (
            partition by family_id
            order by snapshot_ts desc, snapshot_number desc, snapshot_id desc
        ) as rn_any,

        -- Rank snapshots with stoplight data (most recent with stoplight = 1)
        row_number() over (
            partition by family_id
            order by
                case when coalesce(stoplight_skipped, false) = false then 0 else 1 end,
                snapshot_ts desc,
                snapshot_number desc,
                snapshot_id desc
        ) as rn_with_stoplight,

        -- Calculate days since previous snapshot for this family
        extract(epoch from (
            snapshot_ts - lag(snapshot_ts) over (
                partition by family_id
                order by snapshot_ts, snapshot_number, snapshot_id
            )
        )) / 86400.0 as days_since_prev

    from base_snapshot s
),

final as (
    select
        snapshot_id,
        family_id,
        organization_id,
        application_id,
        survey_definition_id,
        project_id,
        snapshot_number,
        snapshot_ts,
        created_at_ts,
        stoplight_skipped,
        anonymous,
        created_by,
        last_modified_by,
        survey_user_id,
        economic,
        stoplight,
        draft_id,
        sign,
        stoplight_client,
        lifemap_url,
        is_last_original,

        -- Derived flags
        is_baseline,
        (rn_any = 1) as is_last_any,
        (rn_with_stoplight = 1) as is_last_with_stoplight,

        -- Temporal metrics
        days_since_prev

    from with_window_calcs
)

select * from final
