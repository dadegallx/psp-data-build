select
    family_id,
    name,
    organization_id,
    application_id,
    is_active,
    anonymous,
    code,
    longitude,
    latitude

from {{ source('ps_families', 'family') }}