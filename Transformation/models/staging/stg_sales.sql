with parsed as (

    select
        regexp_replace(order_id, '[^0-9]', '', 'g') as order_id,
        regexp_replace(customer_id, '[^0-9]', '', 'g') as customer_id,
        customer_name,
        regexp_replace(s.product_id, '[^0-9]', '', 'g') as product_id,
        coalesce(lower(product_name), 'unknown') as product_name,
        od.order_date as order_date,
        coalesce(
            try_cast(ship_date as date),
            try_strptime(ship_date, '%m/%d/%Y')::date,
            try_strptime(ship_date, '%d %b %Y')::date,
            date '1899-12-30' + cast(ship_date as integer)
        ) as ship_date,
        cast(s.quantity as int) as quantity,
        {{ normalize_decimal_separator('s.unit_price') }} as unit_price_normalized,
        {{ normalize_decimal_separator('amount') }} as amount,
        coalesce(lower(regexp_replace(category, '[^a-zA-Z ]', '', 'g')), 'unknown') as category,
        coalesce(lower(regexp_replace(segment, '[^a-zA-Z ]', '', 'g')), 'unknown') as segment,
        coalesce(lower(regexp_replace(order_channel, '[^a-zA-Z ]', '', 'g')), 'unknown') as order_channel,
        {{ percentage_trans('discount') }} as discount,
        {{ percentage_trans('tax') }} as tax
    from {{ source('raw', 'sales') }} s
    left join lateral (
        select coalesce(
            try_cast(s.order_date as date),
            try_strptime(s.order_date, '%m/%d/%Y')::date,
            try_strptime(s.order_date, '%d %b %Y')::date,
            date '1899-12-30' + try_cast(s.order_date as integer)
        ) as order_date
    ) od on true

),

priced as (

    select
        order_id,
        customer_id,
        customer_name,
        product_id,
        product_name,
        order_date,
        ship_date,
        quantity,
        last_value(unit_price_normalized ignore nulls) over (
            partition by product_id
            order by order_date
            rows between unbounded preceding and current row
        ) as unit_price,
        amount,
        category,
        segment,
        order_channel,
        discount,
        tax
    from parsed

)

select
    p.order_id,
    p.customer_id,
    p.customer_name,
    p.product_id,
    p.product_name,
    p.order_date,
    p.ship_date,
    p.quantity,
    p.unit_price,
    p.amount,
    p.category,
    p.segment,
    p.order_channel,
    p.discount,
    p.tax,
    cast(
        coalesce(cast(regexp_replace(p.unit_price, '[^0-9.]', '', 'g') as decimal(10, 2)), 0.00)
        * (1 - coalesce(p.discount, 0.00))
        * p.quantity
        as decimal(10, 2)
    ) as correct_amount
from priced p
