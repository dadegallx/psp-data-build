with source as (
    select * from {{ source('data_collect', 'snapshot_stoplight') }}
),

renamed as (
    select
        -- Primary key
        id as snapshot_stoplight_id,

        -- Foreign keys
        snapshot_id,

        -- Attributes
        code_name as indicator_code_name,
        value as indicator_status_value,  -- 1=Red, 2=Yellow, 3=Green, NULL=Skipped

        -- Audit fields
        to_timestamp(updated_at / 1000) as updated_at,
        updated_by,
        created_date as created_at

    from source
)

select * from renamed
