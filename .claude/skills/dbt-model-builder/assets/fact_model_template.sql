{{
  config(
    materialized='table',
    tags=['mart', 'fact', 'core']
  )
}}

with events as (
    select * from {{ ref('stg_events') }}
),

dim_entity_1 as (
    select * from {{ ref('dim_entity_1') }}
),

dim_entity_2 as (
    select * from {{ ref('dim_entity_2') }}
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key([
            'events.event_id',
            'events.entity_id'
        ]) }} as fact_key,

        -- Foreign keys to dimensions
        to_char(events.event_date, 'YYYYMMDD')::integer as date_key,
        dim_entity_1.entity_1_key,
        dim_entity_2.entity_2_key,

        -- Degenerate dimensions
        events.event_id,
        events.event_type,
        events.status,

        -- Measures
        events.quantity,
        events.amount,
        events.calculated_value,

        -- Timestamps
        events.event_timestamp,
        events.created_at

    from events
    inner join dim_entity_1 on events.entity_1_id = dim_entity_1.entity_1_id
    left join dim_entity_2 on events.entity_2_id = dim_entity_2.entity_2_id

    where events.event_date is not null
)

select * from final
