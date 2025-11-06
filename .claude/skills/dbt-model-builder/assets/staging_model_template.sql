{{
  config(
    materialized='view',
    tags=['staging']
  )
}}

with source as (
    select * from {{ source('schema_name', 'table_name') }}
),

renamed as (
    select
        -- Primary key
        id as entity_id,

        -- Foreign keys
        parent_id,
        related_id,

        -- Attributes
        name,
        status,
        description,

        -- Dates and timestamps
        created_at,
        updated_at

    from source
)

select * from renamed
