with source as (
    select * from {{ source('ps_families', 'family_members') }}
),

renamed as (
    select
        -- Primary key
        id as family_member_id,

        -- Foreign keys
        family_id,

        -- Attributes
        first_participant,
        active as is_active,
        anonymous as is_anonymous,

        -- Gender Normalization (M/F/Other convention)
        case
            when gender in ('M', 'MASCULINO', 'LALAKI', 'GASON', 'Male') then 'Male'
            when gender in ('F', 'FEMENINO', 'BABAE', 'FI', 'Female') then 'Female'
            -- Catch 'O', 'ANON_DATA', 'PREFIERO...', and NULLs
            else 'Other'
        end as gender,

        -- Country Standardization (ISO Alpha-2 or Unknown)
        coalesce(nullif(birth_country, ''), 'Unknown') as birth_country,

        -- Audit fields
        created_date as created_at,
        last_modified_date as updated_at

    from source
    where family_id is not null  -- Exclude orphan records
)

select * from renamed
