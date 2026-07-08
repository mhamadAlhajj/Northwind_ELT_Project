with parsed as (

    select
        regexp_replace(order_id, '[^0-9]', '', 'g') as order_id,
        regexp_replace(customer_id, '[^0-9]', '', 'g') as customer_id,
        trim(customer_name) as customer_name,
        regexp_replace(product_id, '[^0-9]', '', 'g') as product_id,
        trim(coalesce(lower(product_name), 'unknown')) as product_name,
        {{date_transformation('order_date')}} as order_date,
        {{date_transformation('ship_date')}} as ship_date,
        cast(quantity as int) as quantity,
        {{ normalize_decimal_separator('unit_price') }} as unit_price_normalized,
        {{ normalize_decimal_separator('amount') }} as amount,
        coalesce(lower(trim(regexp_replace(category, '[^a-zA-Z ]', '', 'g'))), 'unknown') as category,
        coalesce(lower(trim(regexp_replace(segment, '[^a-zA-Z ]', '', 'g'))), 'unknown') as segment,
        coalesce(lower(trim(regexp_replace(order_channel, '[^a-zA-Z ]', '', 'g'))), 'unknown') as order_channel,
        {{ percentage_transformation('discount') }} as discount,
        {{ percentage_transformation('tax') }} as tax,
        _dlt_load_id,
        _dlt_id
    from {{ source('raw', 'sales') }}

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
        -- Get the last non-null value and use it to fill rows where unit_price is null
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
        tax,
        _dlt_load_id,
        _dlt_id
    from parsed
),

typed as (

    select
        try_cast(p.order_id as int) as order_id,
        try_cast(p.customer_id as int) as customer_id,
        p.customer_name,
        try_cast(p.product_id as int) as product_id,
        p.product_name,
        p.order_date,
        p.ship_date,
        p.quantity,
        try_cast(p.unit_price as decimal(10,2)) as unit_price,
        try_cast(p.amount as decimal(10,2)) as amount,
        p.category,
        p.segment,
        p.order_channel,
        p.discount,
        p.tax,
        _dlt_load_id,
        _dlt_id
    from priced p

),

flagged as (

    select
        *,
        nullif(
            concat_ws(
                ', ',
                case when order_id      is null then 'missing_order_id' end,
                case when customer_id   is null then 'missing_customer_id' end,
                case when product_id    is null then 'missing_product_id' end,
                case when order_date    is null then 'missing_order_date' end,
                case when ship_date     is null then 'missing_ship_date' end,
                case when quantity      is null then 'missing_quantity' end,
                case when quantity is not null and quantity <= 0 then 'invalid_quantity' end,
                case when unit_price    is null then 'missing_unit_price' end,
                case when unit_price is not null and unit_price < 0 then 'invalid_unit_price' end,
                case when order_date is not null and ship_date is not null and ship_date < order_date
                    then 'ship_before_order' end,
                case when amount is null then 'missing_amount' end,
                case when amount is not null and amount < 0 then 'invalid_amount' end
            ),
            ''
        ) as quarantine_reason
    from typed

)

select
    order_id,
    customer_id,
    customer_name,
    product_id,
    product_name,
    order_date,
    ship_date,
    quantity,
    unit_price,
    amount,
    category,
    segment,
    order_channel,
    discount,
    tax,
    quarantine_reason,
    quarantine_reason is not null as is_quarantined,
    _dlt_load_id,
    _dlt_id 
from flagged
