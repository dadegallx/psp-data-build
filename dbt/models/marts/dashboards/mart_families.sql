{{ config(materialized='table', alias='Families') }}

with families as (
    select * from {{ ref('dim_family') }}
),

organizations as (
    select * from {{ ref('dim_organization') }}
),

final as (
    select
        families.family_id,
        families.is_anonymous,
        families.country as family_country,
        families.latitude,
        families.longitude,

        -- Organization info
        organizations.organization_name,
        organizations.organization_country_code,
        organizations.organization_type

    from families
    left join organizations on families.organization_id = organizations.organization_id
)

select * from final
