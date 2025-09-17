select
    survey_definition_id,
    code_name,
    max(definition_count) as duplicate_count,
    string_agg(distinct short_name, ', ' order by short_name) as conflicting_names,
    string_agg(definition_id::text, ', ' order by definition_id) as definition_ids

from {{ ref('int_indicator_definitions_deduped') }}
where definition_count > 1
group by survey_definition_id, code_name