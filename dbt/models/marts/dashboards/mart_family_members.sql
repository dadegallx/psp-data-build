{{ config(materialized='table') }}

with members as (
    select * from {{ ref('stg_family_members') }}
),

families as (
    select * from {{ ref('dim_family') }}
),

organizations as (
    select * from {{ ref('dim_organization') }}
),

final as (
    select
        members.family_member_id,
        members.family_id,
        members.gender,
        members.birth_country,
        members.created_at as member_created_at,

        -- Context
        families.country as family_country,
        organizations.organization_name,
        organizations.organization_country_code

    from members
    left join families on members.family_id = families.family_id
    left join organizations on families.organization_id = organizations.organization_id
)

select * from final
