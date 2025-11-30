with source as (
    select * from {{ source('data_collect', 'survey_stoplight_dimension') }}
),

renamed as (
    select
        -- Primary key
        id as dimension_id,

        -- Attributes
        code_name as dimension_code,
        lower(trim(met_name)) as dimension_met_name,  -- normalized for translation join
        status as dimension_status

    from source
)

select * from renamed
