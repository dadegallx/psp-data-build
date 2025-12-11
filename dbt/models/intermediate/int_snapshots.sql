{{
    config(
        materialized='table',
        schema='staging',
        tags=['intermediate']
    )
}}

with snapshots as (
    select * from {{ ref('stg_snapshots') }}
),

final as (
    select
        *,
        -- Calculate is_last dynamically to fix data integrity issues in source
        case 
            when row_number() over (
                partition by family_id 
                order by snapshot_date desc, created_at desc, snapshot_id desc
            ) = 1 
            then true 
            else false 
        end as is_last
    from snapshots
)

select * from final
