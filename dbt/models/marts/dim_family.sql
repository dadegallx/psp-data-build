with families as (
    select * from {{ ref('stg_families') }}
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['family_id']) }} as family_key,

        -- Natural key
        family_id,

        -- Family attributes
        family_is_active,
        is_anonymous,

        -- Geographic attributes
        country,
        latitude,
        longitude

    from families
)

select * from final
