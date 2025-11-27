with source as (
    select * from {{ source('data_collect', 'survey_stoplight_indicator') }}
),

renamed as (
    select
        -- Primary key
        id as indicator_template_id,

        -- Foreign keys
        survey_dimension_id as dimension_id,

        -- Attributes (short_name/description normalized for translation joins)
        code_name as indicator_template_code_name,
        lower(trim(met_short_name)) as indicator_template_short_name,
        lower(trim(met_description)) as indicator_template_description

    from source
)

select * from renamed
