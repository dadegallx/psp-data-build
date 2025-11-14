-- Custom test: Validate that household_monthly_income and income_currency_code are always paired
-- If income exists, currency must exist (and vice versa)
-- This ensures data integrity for the householdMonthlyIncome economic field

with income_currency_check as (
    select
        family_economic_snapshot_key,
        snapshot_id,
        household_monthly_income,
        income_currency_code
    from {{ ref('fact_family_economic_snapshot') }}
    where household_monthly_income is not null
       or income_currency_code is not null
),

pairing_failures as (
    select
        family_economic_snapshot_key,
        snapshot_id,
        case
            when household_monthly_income is not null and income_currency_code is null
                then 'income_without_currency'
            when household_monthly_income is null and income_currency_code is not null
                then 'currency_without_income'
        end as failure_type,
        household_monthly_income,
        income_currency_code
    from income_currency_check
    where (household_monthly_income is not null and income_currency_code is null)
       or (household_monthly_income is null and income_currency_code is not null)
)

-- Return rows that fail the test (unpaired income/currency)
select * from pairing_failures
