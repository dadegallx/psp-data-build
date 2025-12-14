with source as (
    select * from {{ source('data_collect', 'survey_stoplight_dimension') }}
),

renamed as (
    select
        -- Primary key
        id as dimension_id,

        -- Attributes
        lower(trim(met_name)) as dimension_met_name,  -- normalized for translation join
        status as dimension_is_active,

        -- Audit fields
        created_date as dimension_created_at,
        last_modified_date as dimension_updated_at

    from source
)

select * from renamed
