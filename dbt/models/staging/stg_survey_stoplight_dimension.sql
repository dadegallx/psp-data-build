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

        -- Core dimension flag (whitelist of 6 primary poverty dimensions)
        lower(trim(met_name)) in (
            'housingandinfrastructure.name',
            'healthandenvironment.name',
            'educationandculture.name',
            'incomeandemployment.name',
            'interiorityandmotivation.name',
            'organizationandparticipation.name'
        ) as is_core_dimension,

        -- Audit fields
        created_date as dimension_created_at,
        last_modified_date as dimension_updated_at

    from source
)

select * from renamed
