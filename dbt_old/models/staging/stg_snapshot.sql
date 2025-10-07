select
    id as snapshot_id,
    family_id,
    survey_definition_id,
    TO_TIMESTAMP(snapshot_date / 1000) as snapshot_date,
    snapshot_number,
    is_last,
    anonymous,
    stoplight_skipped

from {{ source('data_collect', 'snapshot') }}