-- Custom test: Validate that mart_progress only includes families with 2+ surveys
-- All families in mart_progress should have total_surveys_completed >= 2

select
    family_id,
    family_code,
    total_surveys_completed
from {{ ref('mart_progress') }}
where total_surveys_completed < 2  -- This should return 0 rows

-- If this query returns any rows, the test fails
-- because it means we have families with less than 2 surveys in the progress mart
