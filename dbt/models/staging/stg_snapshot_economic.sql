with source as (
    select * from {{ source('data_collect', 'snapshot_economic') }}
),

renamed as (
    select
        -- Primary key
        id as snapshot_economic_id,

        -- Foreign keys
        snapshot_id,

        -- Question identifier (normalized for joins)
        lower(trim(code_name)) as code_name,

        -- Answer type and raw value (default to 'text' when missing)
        coalesce(
            case when answer_type = 'string' then 'text' else answer_type end,
            'text'
        ) as answer_type,
        value as answer_value,
        multiple_value as answer_multiple_value,

        -- Audit fields
        created_date as snapshot_economic_created_at,
        last_modified_date as snapshot_economic_updated_at

    from source
)

select * from renamed
