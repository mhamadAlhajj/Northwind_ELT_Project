with base as (

    select
        customer_id,
        customer_name,
        country,
        country_name,
        segment,
        order_date
    from {{ ref('int_sales_conformed') }}
    where is_quarantined = false

),

lag_table as (

    select
        customer_id,
        customer_name,
        country,
        segment,
        order_date,
        lag(customer_name) over (partition by customer_id order by order_date) as previous_name,
        lag(country) over (partition by customer_id order by order_date) as previous_country,
        lag(segment) over (partition by customer_id order by order_date) as previous_segment
    from base

),

check_change as (

    select
        customer_id,
        customer_name,
        country,
        segment,
        order_date as valid_from
    from lag_table
    where
        previous_name is null
        or customer_name is distinct from previous_name
        or country is distinct from previous_country
        or segment is distinct from previous_segment

),

add_valid_to as (

    select
        *,
        lead(valid_from) over (partition by customer_id order by valid_from) as valid_to
    from check_change

)

select
    customer_id,
    customer_name,
    country,
    segment,
    valid_from,
    valid_to,
    concat(customer_id, '-', valid_from) as customer_surrogate_id,
    valid_to is null as is_current
from add_valid_to

union all

select
    -1 as customer_id,
    'unknown' as customer_name,
    'unknown' as country,
    'unknown' as segment,
    cast('1900-01-01' as date) as valid_from,
    cast(null as date) as valid_to,
    '-1-unknown' as customer_surrogate_id,
    true as is_current
