{{
  config(
    materialized='table',
    tags=['mart', 'dimension', 'core']
  )
}}

with entities as (
    select * from {{ ref('stg_entities') }}
),

related_data as (
    select * from {{ ref('stg_related_data') }}
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['entities.entity_id']) }} as entity_key,

        -- Natural key
        entities.entity_id,

        -- Attributes
        entities.entity_code,
        entities.entity_name,
        entities.entity_type,
        entities.description,
        entities.is_active,

        -- Related attributes from other tables
        related_data.category,
        related_data.status,

        -- Hierarchical attributes (if applicable)
        entities.parent_id,
        entities.parent_name,

        -- Geographic attributes (if applicable)
        entities.country_code,
        entities.region,
        entities.city,

        -- Audit fields
        entities.created_at,
        entities.updated_at

    from entities
    left join related_data on entities.entity_id = related_data.entity_id
)

select * from final
