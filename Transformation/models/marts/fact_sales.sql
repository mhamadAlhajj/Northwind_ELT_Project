with matched as (
    select
        isc.order_line_id,
        isc.order_id,
        isc.order_date,
        isc.ship_date,
        isc.quantity,
        isc.amount_usd as gross_amount_usd,
        isc.amount_usd * isc.discount as discount_usd,
        isc.amount_usd * (1 - isc.discount) as net_amount_usd,
        isc.order_channel,
        isc.discount,
        isc._dlt_id,
        isc._dlt_load_id,
        isc.loaded_date,
        coalesce(dc.customer_surrogate_id, '-1-unknown') as customer_key,
        coalesce(dp.product_surrogate_id, '-1-unknown') as product_key,
    from {{ ref('int_sales_conformed') }} isc
    left join {{ ref('dim_customer') }} dc
        on isc.customer_id = dc.customer_id
        and isc.order_date >= dc.valid_from
        and (dc.valid_to is null or isc.order_date < dc.valid_to)
    left join {{ref('dim_product')}} dp 
        on isc.product_id = dp.product_id
        and isc.order_date >= dp.valid_from
        and (dp.valid_to is null or isc.order_date < dp.valid_to)
)
select * from matched