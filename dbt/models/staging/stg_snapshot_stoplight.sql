with source as (
    select * from {{ source('data_collect', 'snapshot_stoplight') }}
),

renamed as (
    select
        -- Primary key
        id as snapshot_stoplight_id,

        -- Foreign keys
        snapshot_id,

        -- Attributes (normalized for joins)
        lower(trim(code_name)) as indicator_code_name,
        value as indicator_status_value,  -- 1=Red, 2=Yellow, 3=Green, 0=Skipped
        additional as is_additional,

        -- Audit fields
        created_date as created_at,
        to_timestamp(updated_at / 1000) as updated_at

    from source
)

select * from renamed
