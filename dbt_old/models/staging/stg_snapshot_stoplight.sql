select
    id as indicator_response_id,
    snapshot_id,
    code_name,
    value,
    additional

from {{ source('data_collect', 'snapshot_stoplight') }}