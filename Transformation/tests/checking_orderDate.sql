select * from {{ref('stg_sales')}}
where order_date > ship_date and is_quarantined = false