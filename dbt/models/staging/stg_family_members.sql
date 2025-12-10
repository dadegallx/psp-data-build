with source as (
    select * from {{ source('ps_families', 'family_members') }}
),

renamed as (
    select
        -- Primary key
        id as family_member_id,

        -- Foreign keys
        family_id,


        -- Attributes with Normalization
        -- Gender Normalization (M/F/Other convention)
        case
            when gender in ('M', 'MASCULINO', 'LALAKI', 'GASON', 'Male') then 'Male'
            when gender in ('F', 'FEMENINO', 'BABAE', 'FI', 'Female') then 'Female'
            -- Catch 'O', 'ANON_DATA', 'PREFIERO...', and NULLs
            else 'Other' 
        end as gender,

        -- Country Standardization (ISO Alpha-2 or Unknown)
        -- Most data is already ISO-2, we handle NULL/Empty map to Unknown for cleaner BI interaction
        coalesce(nullif(birth_country, ''), 'Unknown') as birth_country,

        -- Original Attributes (optional, keeping for lineage if needed, but not primary)
        -- birth_country as original_birth_country,

        -- Audit fields
        created_date as created_at

    from source
)

select * from renamed
