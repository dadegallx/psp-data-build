with families as (
    select * from {{ ref('stg_families') }}
),

final as (
    select
        -- Primary key
        family_id,

        -- Family attributes
        is_anonymous,

        -- Geographic attributes
        country,
        latitude,
        longitude

    from families
)

select * from final
