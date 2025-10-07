{{ config(
    materialized="view",
    tags=["staging", "dimension"]
) }}

with source as (
    select * from {{ source('ps_network', 'applications') }}
),

renamed as (
    select
        -- Primary key
        id as application_id,

        -- Application attributes
        name as application_name,
        description,
        coalesce(is_active, true) as is_active,
        country,
        country_code,
        language,

        -- Partner information
        partner_type,

        -- Branding
        logo_url,
        labels,

        -- Audit fields
        created_by,
        last_modified_by,
        to_timestamp(extract(epoch from created_date)) as created_at_ts,
        to_timestamp(extract(epoch from last_modified_date)) as last_modified_at_ts

    from source
)

select * from renamed
