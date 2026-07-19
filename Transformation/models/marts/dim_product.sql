with base as (

    -- unit_price_usd uses the same rate as amount_usd (int_sales_conformed's as-of FX join),
    -- so price changes are compared in one currency instead of whatever currency the order happened to be in
    select
        product_id,
        product_name,
        category,
        unit_price / rate as unit_price_usd,
        order_date
    from {{ ref('int_sales_conformed') }}
    where is_quarantined = false

),

lag_table as (

    select
        product_id,
        product_name,
        category,
        unit_price_usd,
        order_date,
        lag(product_name) over (partition by product_id order by order_date) as previous_name,
        lag(category) over (partition by product_id order by order_date) as previous_category,
        lag(unit_price_usd) over (partition by product_id order by order_date) as previous_unit_price_usd
    from base

),

check_change as (

    select
        product_id,
        product_name,
        category,
        unit_price_usd,
        order_date as valid_from
    from lag_table
    where previous_name is null
        or product_name is distinct from previous_name
        or category is distinct from previous_category
        or unit_price_usd is distinct from previous_unit_price_usd

),

add_valid_to as (

    select
        *,
        lead(valid_from) over (partition by product_id order by valid_from) as valid_to
    from check_change

)

select
    product_id,
    product_name,
    category,
    unit_price_usd,
    valid_from,
    valid_to,
    concat(product_id, '-', valid_from) as product_surrogate_id,
    valid_to is null as is_current
from add_valid_to

union all

select
    -1 as product_id,
    'unknown' as product_name,
    'unknown' as category,
    0 as unit_price_usd,
    cast('1900-01-01' as date) as valid_from,
    cast(null as date) as valid_to,
    '-1-unknown' as product_surrogate_id,
    true as is_current
