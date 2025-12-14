with source as (
    select * from {{ source('data_collect', 'survey_stoplight_color') }}
),

renamed as (
    select
        -- Primary key
        id as survey_stoplight_color_id,

        -- Foreign keys
        survey_stoplight_id as survey_indicator_id,

        -- Attributes
        value as color_value,  -- 1=Red, 2=Yellow, 3=Green
        description as color_description,

        -- Audit fields
        created_at,
        updated_at

    from source
)

select * from renamed
