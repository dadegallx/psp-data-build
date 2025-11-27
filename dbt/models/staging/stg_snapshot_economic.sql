with source as (
    select * from {{ source('data_collect', 'snapshot_economic') }}
),

renamed as (
    select
        -- Primary key
        id as snapshot_economic_id,

        -- Foreign keys
        snapshot_id,

        -- Question identifier
        code_name,

        -- Answer type and raw value
        answer_type,
        value as answer_value,
        multiple_value as answer_multiple_value,

        -- Audit fields
        created_date,
        last_modified_date

    from source
)

select * from renamed
