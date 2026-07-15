with cte_sales as (
    select distinct order_id,
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
        country,
        discount,
        tax,
        quarantine_reason,
        quarantine_reason is not null as is_quarantined,
        _dlt_load_id,
        _dlt_id
    from {{ref('stg_sales')}}
),
cte_load_date as (
    select load_id , inserted_at as loaded_date
    from {{source('raw','_dlt_loads')}}
),
cte_join as (
    select s.* , ld.loaded_date  
    from cte_sales s
    inner join cte_load_date ld
    on ld.load_id = s._dlt_load_id
)
select * 
from (
-- The purpose of the row number here is to remove duplicates when the same order ID and product id appears more than once.
-- This duplication may occur because the same order was loaded late or due to a data loading issue.
select * , row_number() over (partition by order_id ,product_id, sign(quantity) order by loaded_date desc) as rn
from cte_join
where is_quarantined = false
)
where rn = 1