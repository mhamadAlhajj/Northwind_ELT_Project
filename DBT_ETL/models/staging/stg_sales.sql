select REGEXP_REPLACE(order_id, '[^0-9]', '', 'g') AS order_id ,
REGEXP_REPLACE(customer_id, '[^0-9]', '', 'g') AS customer_id ,
customer_name,
coalesce(
    date '1899-12-30' + cast(order_date as integer),
    try_cast(order_date__v_text as date),
    try_strptime(order_date__v_text, '%m/%d/%Y')::date,
    try_strptime(order_date__v_text, '%d %b %Y')::date
) as order_date ,
coalesce(
    try_cast(ship_date as date),
    try_strptime(ship_date, '%m/%d/%Y')::date,
    try_strptime(ship_date, '%d %b %Y')::date,
    date '1899-12-30' + cast(ship_date as integer)
) as ship_date,

from {{source('raw', 'sales')}}
