with typed as (

    select
        try_cast(rate_date as date) as rate_date,
        try_cast(actual_date as date) as actual_date,
        trim(base) as base,
        trim(currency) as currency,
        try_cast(rate as float) as rate,
        _dlt_load_id,
        _dlt_id
    from {{ source('raw', 'fx_rates') }}

),

flagged as (

    select
        *,
        nullif(
            concat_ws(
                ', ',
                case when rate_date is null then 'missing_rate_date' end,
                case when currency  is null then 'missing_currency' end,
                case when base      is null then 'missing_base' end,
                case when rate      is null then 'missing_rate' end,
                case when rate is not null and rate <= 0 then 'invalid_rate' end
            ),
            ''
        ) as quarantine_reason
    from typed

)

select
    rate_date,
    actual_date,
    base,
    currency,
    rate,
    _dlt_load_id,
    _dlt_id,
    quarantine_reason,
    quarantine_reason is not null as is_quarantined
from flagged
