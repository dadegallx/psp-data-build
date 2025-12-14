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
        value as indicator_status_value,  -- 0=Skipped, 1=Red, 2=Yellow, 3=Green, 9=N/A
        additional as is_additional,

        -- Audit fields
        created_date as created_at,
        to_timestamp(updated_at / 1000) as updated_at

    from source
    where value in (0, 1, 2, 3, 9)
)

select * from renamed
