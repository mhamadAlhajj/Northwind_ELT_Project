with countries as (

    select
        _dlt_id,
        trim(names__common) as common_name,
        trim(names__official) as official_name,
        codes__alpha_2 as alpha_2,
        codes__alpha_3 as alpha_3,
        codes__ccn3 as ccn3,
        trim(region) as region
    from {{ source('raw', 'countries') }}

),

currencies as (

    select
        _dlt_parent_id as country_id,
        list(trim(code)) as currency_codes,
        list(trim(name)) as currency_names,
        list(trim(symbol)) as currency_symbols
    from {{ source('raw', 'countries__currencies') }}
    group by _dlt_parent_id

),

joined as (

    select
        c.common_name,
        c.official_name,
        c.alpha_2,
        c.alpha_3,
        c.ccn3,
        c.region,
        cur.currency_codes,
        cur.currency_names,
        cur.currency_symbols
    from countries c
    left join currencies cur on cur.country_id = c._dlt_id

),

flagged as (

    select
        *,
        nullif(
            concat_ws(
                ', ',
                case when common_name    is null then 'missing_common_name' end,
                case when alpha_2        is null then 'missing_alpha_2' end,
                case when alpha_3        is null then 'missing_alpha_3' end,
                case when ccn3           is null then 'missing_ccn3' end,
                case when currency_codes is null then 'missing_currency' end
            ),
            ''
        ) as quarantine_reason
    from joined

)

select
    common_name,
    official_name,
    alpha_2,
    alpha_3,
    ccn3,
    region,
    currency_codes,
    currency_names,
    currency_symbols,
    quarantine_reason,
    quarantine_reason is not null as is_quarantined
from flagged
